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


#import "S3Request.h"
#import "HTTP.h"
#import "URLConnection.h"
#import "S3Service.h"
#import "RegexKitLite.h"
#import "NSError_extra.h"
#import "S3AuthorizationProvider.h"
#import "S3ErrorResult.h"
#import "AWSRegion.h"
#import "HTTPConnectionFactory.h"
#import "AWSRegion.h"
#import "TargetConnection.h"


#define INITIAL_RETRY_SLEEP (0.5)
#define RETRY_SLEEP_GROWTH_FACTOR (1.5)
#define MAX_RETRY_SLEEP (5.0)


@implementation S3Request
- (id)initWithMethod:(NSString *)theMethod endpoint:(NSURL *)theEndpoint path:(NSString *)thePath queryString:(NSString *)theQueryString authorizationProvider:(S3AuthorizationProvider *)theSAP error:(NSError **)error {
    return [self initWithMethod:theMethod endpoint:theEndpoint path:thePath queryString:theQueryString authorizationProvider:theSAP dataTransferDelegate:nil error:error];
}
- (id)initWithMethod:(NSString *)theMethod endpoint:(NSURL *)theEndpoint path:(NSString *)thePath queryString:(NSString *)theQueryString authorizationProvider:(S3AuthorizationProvider *)theSAP dataTransferDelegate:(id<DataTransferDelegate>)theDelegate error:(NSError **)error {
    if (self = [super init]) {
        method = [theMethod copy];
        sap = [theSAP retain];
        dataTransferDelegate = theDelegate; // Don't retain it.
        extraRequestHeaders = [[NSMutableDictionary alloc] init];
        responseHeaders = [[NSMutableDictionary alloc] init];

        if (theQueryString != nil) {
            if ([theQueryString hasPrefix:@"?"]) {
                SETNSERROR([S3Service errorDomain], -1, @"query string may not begin with a ?");
                [self release];
                return nil;
            }
            thePath = [[thePath stringByAppendingString:@"?"] stringByAppendingString:theQueryString];
        }
        NSString *urlString = [NSString stringWithFormat:@"%@%@", [theEndpoint description], thePath];
        url = [[NSURL alloc] initWithString:urlString];
        if (url == nil) {
            SETNSERROR([S3Service errorDomain], -1, @"invalid URL: %@", urlString);
            [self release];
            return nil;
        }
    }
    return self;
}
- (void)dealloc {
    [method release];
    [url release];
    [sap release];
    [requestBody release];
    [extraRequestHeaders release];
    [responseHeaders release];
    [super dealloc];
}
- (void)setRequestBody:(NSData *)theRequestBody {
    [theRequestBody retain];
    [requestBody release];
    requestBody = theRequestBody;
}
- (void)setRequestHeader:(NSString *)value forKey:(NSString *)key {
    [extraRequestHeaders setObject:value forKey:key];
}
- (int)httpResponseCode {
    return httpResponseCode;
}
- (NSString *)responseHeaderForKey:(NSString *)theKey {
    return [responseHeaders objectForKey:theKey];
}
- (NSData *)dataWithTargetConnectionDelegate:(id<TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    NSAutoreleasePool *pool = nil;
    NSTimeInterval sleepTime = INITIAL_RETRY_SLEEP;
    NSData *responseData = nil;
    NSError *myError = nil;
    for (;;) {
        [pool drain];
        pool = [[NSAutoreleasePool alloc] init];
        BOOL needRetry = NO;
        BOOL needSleep = NO;
        myError = nil;
        responseData = [self dataOnce:&myError];
        if (responseData != nil) {
            break;
        }
        
        HSLogDebug(@"S3Request dataOnce failed; %@", myError);
        
        if ([myError isErrorWithDomain:[S3Service errorDomain] code:ERROR_NOT_FOUND]) {
            break;
        }
        if ([myError isErrorWithDomain:[S3Service errorDomain] code:ERROR_TEMPORARY_REDIRECT]) {
            NSString *location = [[myError userInfo] objectForKey:@"location"];
            HSLogDebug(@"redirecting %@ to %@", url, location);
            [url release];
            url = [[NSURL alloc] initWithString:location];
            if (url == nil) {
                HSLogError(@"invalid redirect URL %@", location);
                myError = [NSError errorWithDomain:[S3Service errorDomain] code:-1 description:[NSString stringWithFormat:@"invalid redirect URL %@", location]];
                break;
            }
            needRetry = YES;
        } else if ([myError isErrorWithDomain:[S3Service errorDomain] code:S3SERVICE_ERROR_AMAZON_ERROR]) {
            int httpStatusCode = [[[myError userInfo] objectForKey:@"HTTPStatusCode"] intValue];
            NSString *amazonCode = [[myError userInfo] objectForKey:@"AmazonCode"];
            
            if ([amazonCode isEqualToString:@"RequestTimeout"] || [amazonCode isEqualToString:@"RequestTimeoutException"]) {
                needRetry = YES;
            } else if (httpStatusCode == HTTP_INTERNAL_SERVER_ERROR) {
                needRetry = YES;
                needSleep = YES;
            } else if (httpStatusCode == HTTP_SERVICE_NOT_AVAILABLE) {
                needRetry = YES;
                needSleep = YES;
            } else if (httpStatusCode == HTTP_CONFLICT && [amazonCode isEqualToString:@"OperationAborted"]) {
                // "A conflicting conditional operation is currently in progress against this resource. Please try again."
                // Happens sometimes when putting bucket lifecycle policy.
                needRetry = YES;
                needSleep = YES;
            }
        } else if ([myError isConnectionResetError]) {
            needRetry = YES;
        } else if ([myError isTransientError]) {
            needRetry = YES;
            needSleep = YES;
        }

        if (!needRetry || ![theDelegate targetConnectionShouldRetryOnTransientError:&myError]) {
            HSLogError(@"%@ %@: %@", method, url, myError);
            break;
        }
        
        HSLogDetail(@"retrying %@ %@: %@", method, url, myError);
        if (needSleep) {
            [NSThread sleepForTimeInterval:sleepTime];
            sleepTime *= RETRY_SLEEP_GROWTH_FACTOR;
            if (sleepTime > MAX_RETRY_SLEEP) {
                sleepTime = MAX_RETRY_SLEEP;
            }
        }
    }
    [responseData retain];
    if (responseData == nil) {
        [myError retain];
    }
    [pool drain];
    [responseData autorelease];
    if (responseData == nil) {
        [myError autorelease];
        SETERRORFROMMYERROR;
    }
    
    return responseData;
}


#pragma mark internal
- (NSData *)dataOnce:(NSError **)error {
    id <HTTPConnection> conn = [[[HTTPConnectionFactory theFactory] newHTTPConnectionToURL:url method:method dataTransferDelegate:dataTransferDelegate] autorelease];
    if (conn == nil) {
        return nil;
    }
    [conn setRequestHostHeader];
    [conn setRFC822DateRequestHeader];
    if (requestBody != nil) {
        [conn setRequestHeader:[NSString stringWithFormat:@"%lu", (unsigned long)[requestBody length]] forKey:@"Content-Length"];
    }
    for (NSString *headerKey in [extraRequestHeaders allKeys]) {
        [conn setRequestHeader:[extraRequestHeaders objectForKey:headerKey] forKey:headerKey];
    }
    if (![sap setAuthorizationRequestHeaderOnHTTPConnection:conn error:error]) {
        return nil;
    }
    bytesUploaded = 0;
    
    HSLogDebug(@"%@ %@", method, url);
    
    NSData *response = [conn executeRequestWithBody:requestBody error:error];
    if (response == nil) {
        return nil;
    }
    
    [responseHeaders setDictionary:[conn responseHeaders]];
    
    httpResponseCode = [conn responseCode];
    if (httpResponseCode >= 200 && httpResponseCode <= 299) {
        HSLogDebug(@"HTTP %d; returning response length=%ld", httpResponseCode, (long)[response length]);
        return response;
    }
    
    HSLogTrace(@"http response body: %@", [[[NSString alloc] initWithBytes:[response bytes] length:[response length] encoding:NSUTF8StringEncoding] autorelease]);
    if (httpResponseCode == HTTP_NOT_FOUND) {
        HSLogDebug(@"http response body: %@", [[[NSString alloc] initWithBytes:[response bytes] length:[response length] encoding:NSUTF8StringEncoding] autorelease]);
        S3ErrorResult *errorResult = [[[S3ErrorResult alloc] initWithAction:[NSString stringWithFormat:@"%@ %@", method, [url description]] data:response httpErrorCode:httpResponseCode] autorelease];
        NSError *myError = [errorResult error];
        NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithDictionary:[myError userInfo]];
        [userInfo setObject:[NSString stringWithFormat:@"%@ not found", url] forKey:NSLocalizedDescriptionKey];
        myError = [NSError errorWithDomain:[S3Service errorDomain] code:ERROR_NOT_FOUND userInfo:userInfo];
        HSLogDebug(@"%@", myError);
        SETERRORFROMMYERROR;
        return nil;
    }
    if (httpResponseCode == HTTP_METHOD_NOT_ALLOWED) {
        HSLogError(@"%@ 405 error", url);
        SETNSERROR([S3Service errorDomain], ERROR_RRS_NOT_FOUND, @"%@ 405 error", url);
    }
    if (httpResponseCode == HTTP_MOVED_TEMPORARILY) {
        NSString *location = [conn responseHeaderForKey:@"Location"];
        NSDictionary *userInfo = [NSDictionary dictionaryWithObject:location forKey:@"location"];
        NSError *myError = [NSError errorWithDomain:[S3Service errorDomain] code:ERROR_TEMPORARY_REDIRECT userInfo:userInfo];
        if (error != NULL) {
            *error = myError;
        }
        HSLogDebug(@"returning moved-temporarily error");
        return nil;
    }
    S3ErrorResult *errorResult = [[[S3ErrorResult alloc] initWithAction:[NSString stringWithFormat:@"%@ %@", method, [url description]] data:response httpErrorCode:httpResponseCode] autorelease];
    NSError *myError = [errorResult error];
    HSLogDebug(@"%@ error: %@", conn, myError);
    SETERRORFROMMYERROR;
    
    if ([[[myError userInfo] objectForKey:@"AmazonCode"] isEqualToString:@"MalformedHeaderValue"]) {
        HSLogDebug(@"request headers:");
        for (NSString *headerKey in [conn requestHeaderKeys]) {
            HSLogDebug(@"header: %@ = %@", headerKey, [conn requestHeaderForKey:headerKey]);
        }
    }
    return nil;
}
@end
