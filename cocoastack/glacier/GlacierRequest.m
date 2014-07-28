/*
 Copyright (c) 2009-2014, Stefan Reitshamer http://www.haystacksoftware.com
 
 All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 
 * Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in the
 documentation and/or other materials provided with the distribution.
 
 * Neither the names of PhotoMinds LLC or Haystack Software, nor the names of
 their contributors may be used to endorse or promote products derived from
 this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
 TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "GlacierRequest.h"
#import "GlacierAuthorizationProvider.h"
#import "HTTPConnectionFactory.h"
#import "HTTPConnection.h"
#import "HTTPConnectionFactory.h"
#import "InputStream.h"
#import "HTTP.h"
#import "NSError_Glacier.h"
#import "ISO8601Date.h"
#import "GlacierResponse.h"
#import "GlacierService.h"


#define INITIAL_RETRY_SLEEP (0.5)
#define RETRY_SLEEP_GROWTH_FACTOR (1.5)
#define MAX_RETRY_SLEEP (5.0)


@interface GlacierRequest ()
- (GlacierResponse *)executeOnce:(NSError **)error;
@end


@implementation GlacierRequest

- (id)initWithMethod:(NSString *)theMethod url:(NSURL *)theURL awsRegion:(AWSRegion *)theAWSRegion authorizationProvider:(GlacierAuthorizationProvider *)theGAP retryOnTransientError:(BOOL)theRetryOnTransientError dataTransferDelegate:(id <DataTransferDelegate>)theDataTransferDelegate {
    if (self = [super init]) {
        method = [theMethod retain];
        url = [theURL retain];
        NSAssert(url != nil, @"url may not be nil!");
        awsRegion = [theAWSRegion retain];
        gap = [theGAP retain];
        retryOnTransientError = theRetryOnTransientError;
        dataTransferDelegate = theDataTransferDelegate; // Do not retain.
        extraHeaders = [[NSMutableDictionary alloc] init];
    }
    return self;
}
- (void)dealloc {
    [method release];
    [url release];
    [awsRegion release];
    [gap release];
    [requestData release];
    [extraHeaders release];
    [super dealloc];
}

- (NSString *)errorDomain {
    return @"GlacierRequestErrorDomain";
}
- (void)setRequestData:(NSData *)theRequestData {
    [theRequestData retain];
    [requestData release];
    requestData = theRequestData;
}
- (void)setHeader:(NSString *)value forKey:(NSString *)key {
    [extraHeaders setObject:value forKey:key];
}
- (GlacierResponse *)execute:(NSError **)error {
    NSAutoreleasePool *pool = nil;
    NSTimeInterval sleepTime = INITIAL_RETRY_SLEEP;
    GlacierResponse *theResponse = nil;
    NSError *myError = nil;
    for (;;) {
        [pool drain];
        pool = [[NSAutoreleasePool alloc] init];
        BOOL transientError = NO;
        BOOL needSleep = NO;
        myError = nil;
        theResponse = [self executeOnce:&myError];
        if (theResponse != nil) {
            break;
        }
        if ([myError isErrorWithDomain:[self errorDomain] code:ERROR_NOT_FOUND]) {
            break;
        } else if ([myError isErrorWithDomain:[self errorDomain] code:GLACIER_ERROR_AMAZON_ERROR]) {
            int httpStatusCode = [[[myError userInfo] objectForKey:@"HTTPStatusCode"] intValue];
            NSString *amazonCode = [[myError userInfo] objectForKey:@"AmazonCode"];
            
            if (retryOnTransientError && [amazonCode isEqualToString:@"RequestTimeoutException"]) {
                transientError = YES;
            } else if (retryOnTransientError && httpStatusCode == HTTP_REQUEST_TIMEOUT) { // Maybe the Glacier response body wasn't there, but we still got a 408, so we retry.
                transientError = YES;
            } else if (retryOnTransientError && [[[myError userInfo] objectForKey:@"AmazonMessage"] hasPrefix:@"The request signature we calculated does not match the signature you provided."]) {
                // AWS seems to randomly return this error for some people.
                transientError = YES;
                needSleep = YES;
            } else if (retryOnTransientError && [amazonCode isEqualToString:@"ThrottlingException"]) {
                transientError = YES;
                needSleep = YES;
            } else if (httpStatusCode == HTTP_INTERNAL_SERVER_ERROR) {
                transientError = YES;
                needSleep = YES;
                
            } else if (retryOnTransientError && httpStatusCode == HTTP_SERVICE_NOT_AVAILABLE) {
                transientError = YES;
                needSleep = YES;
            } else if (retryOnTransientError && httpStatusCode == HTTP_VERSION_NOT_SUPPORTED) {
                transientError = YES;
                needSleep = YES;
            } else {
                HSLogError(@"%@ %@: %@", method, url, myError);
                break;
            }
        } else if ([myError isConnectionResetError]) {
            transientError = YES;
        } else if (retryOnTransientError && [myError isTransientError]) {
            transientError = YES;
            needSleep = YES;
        } else {
            HSLogError(@"%@ %@: %@", method, url, myError);
            break;
        }
        
        if (transientError) {
            HSLogDetail(@"retrying %@ %@: %@", method, url, myError);
        }
        if (needSleep) {
            [NSThread sleepForTimeInterval:sleepTime];
            sleepTime *= RETRY_SLEEP_GROWTH_FACTOR;
            if (sleepTime > MAX_RETRY_SLEEP) {
                sleepTime = MAX_RETRY_SLEEP;
            }
        }
    }
    [theResponse retain];
    [myError retain];
    [pool drain];
    [theResponse autorelease];
    [myError autorelease];
    if (error != NULL) { *error = myError; }
    return theResponse;
}


#pragma mark internal
- (GlacierResponse *)executeOnce:(NSError **)error {
    id <HTTPConnection> conn = [[[HTTPConnectionFactory theFactory] newHTTPConnectionToURL:url method:method dataTransferDelegate:dataTransferDelegate] autorelease];
    [conn setDate:[NSDate date]];
    [conn setRequestHostHeader];
    [conn setRequestHeader:[ISO8601Date basicDateTimeStringFromDate:[NSDate date]] forKey:@"x-amz-date"];
    [conn setRequestHeader:@"2012-06-01" forKey:@"x-amz-glacier-version"];
    
    for (NSString *headerKey in [extraHeaders allKeys]) {
        [conn setRequestHeader:[extraHeaders objectForKey:headerKey] forKey:headerKey];
    }
    [conn setRequestHeader:[gap authorizationForAWSRegion:awsRegion connection:conn requestBody:requestData] forKey:@"Authorization"];
    HSLogDebug(@"%@ %@", method, url);
    NSData *responseData = [conn executeRequestWithBody:requestData error:error];
    if (responseData == nil) {
        return nil;
    }
    int code = [conn responseCode];
    if (code >= 200 && code <= 299) {
        HSLogDebug(@"HTTP %d; returning response length=%lu", code, (unsigned long)[responseData length]);
        GlacierResponse *response = [[[GlacierResponse alloc] initWithCode:code headers:[conn responseHeaders] body:responseData] autorelease];
        return response;
    }
    
    if (code == HTTP_NOT_FOUND) {
        SETNSERROR([self errorDomain], ERROR_NOT_FOUND, @"%@ not found", url);
        HSLogDebug(@"returning not-found error");
        return nil;
    }
    if (code == HTTP_METHOD_NOT_ALLOWED) {
        HSLogError(@"%@ 405 error", url);
        SETNSERROR([self errorDomain], ERROR_RRS_NOT_FOUND, @"%@ 405 error", url);
    }
    NSError *myError = [NSError glacierErrorWithDomain:[self errorDomain] httpStatusCode:code responseBody:responseData];
    HSLogDebug(@"%@ %@ error: %@", method, conn, myError);
    if (error != NULL) {
        *error = myError;
    }
    return nil;
}
@end
