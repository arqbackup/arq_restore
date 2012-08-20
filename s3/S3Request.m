/*
 Copyright (c) 2009-2011, Stefan Reitshamer http://www.haystacksoftware.com
 
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
#import "ServerBlob.h"
#import "S3Service.h"
#import "SetNSError.h"
#import "RegexKitLite.h"
#import "NSErrorCodes.h"
#import "NSError_extra.h"
#import "S3AuthorizationProvider.h"
#import "NSError_S3.h"
#import "S3Region.h"
#import "HTTPConnectionFactory.h"
#import "HTTPTimeoutSetting.h"


#define INITIAL_RETRY_SLEEP (0.5)
#define RETRY_SLEEP_GROWTH_FACTOR (1.5)
#define MAX_RETRY_SLEEP (5.0)

@interface S3Request (internal)
- (ServerBlob *)newServerBlobOnce:(NSError **)error;
@end

@implementation S3Request
- (id)initWithMethod:(NSString *)theMethod path:(NSString *)thePath queryString:(NSString *)theQueryString authorizationProvider:(S3AuthorizationProvider *)theSAP useSSL:(BOOL)ssl retryOnTransientError:(BOOL)retry error:(NSError **)error {
    return [self initWithMethod:theMethod path:thePath queryString:theQueryString authorizationProvider:theSAP useSSL:ssl retryOnTransientError:retry httpConnectionDelegate:nil error:error];
}
- (id)initWithMethod:(NSString *)theMethod path:(NSString *)thePath queryString:(NSString *)theQueryString authorizationProvider:(S3AuthorizationProvider *)theSAP useSSL:(BOOL)ssl retryOnTransientError:(BOOL)retry httpConnectionDelegate:(id <HTTPConnectionDelegate>)theHTTPConnectionDelegate error:(NSError **)error {
    HTTPTimeoutSetting *theTimeoutSetting = [[[HTTPTimeoutSetting alloc] init] autorelease];
    return [self initWithMethod:theMethod path:thePath queryString:theQueryString authorizationProvider:theSAP useSSL:ssl retryOnTransientError:retry httpConnectionDelegate:theHTTPConnectionDelegate httpTimeoutSetting:theTimeoutSetting error:error];
}
- (id)initWithMethod:(NSString *)theMethod path:(NSString *)thePath queryString:(NSString *)theQueryString authorizationProvider:(S3AuthorizationProvider *)theSAP useSSL:(BOOL)ssl retryOnTransientError:(BOOL)retry httpConnectionDelegate:(id <HTTPConnectionDelegate>)theHTTPConnectionDelegate httpTimeoutSetting:(HTTPTimeoutSetting *)theTimeoutSetting error:(NSError **)error {
    if (self = [super init]) {
        method = [theMethod copy];
        sap = [theSAP retain];
        retryOnTransientError = retry;
        httpTimeoutSetting = [theTimeoutSetting retain];
        httpConnectionDelegate = theHTTPConnectionDelegate; // Don't retain it.
        extraHeaders = [[NSMutableDictionary alloc] init];

        NSString *endpoint = nil;
        if ([thePath isEqualToString:@"/"]) {
            endpoint = [[S3Region usStandard] endpoint];
        } else {
            NSRange s3BucketRange = [thePath rangeOfRegex:@"^/([^/]+)" capture:1];
            NSAssert(s3BucketRange.location != NSNotFound, @"invalid path -- missing s3 bucket name!");
            NSString *s3BucketName = [thePath substringWithRange:s3BucketRange];
            endpoint = [[S3Region s3RegionForBucketName:s3BucketName] endpoint];
        }
        if (theQueryString != nil) {
            thePath = [thePath stringByAppendingString:theQueryString];
        }
        NSString *urlString = [NSString stringWithFormat:@"http%@://%@%@", (ssl ? @"s" : @""), endpoint, thePath];
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
    [httpTimeoutSetting release];
    [sap release];
    [blob release];
    [blobData release];
    [extraHeaders release];
    [super dealloc];
}
- (void)setBlob:(Blob *)theBlob length:(uint64_t)theLength {
    if (blob != theBlob) {
        [blob release];
        blob = [theBlob retain];
    }
    length = theLength;
}
- (void)setHeader:(NSString *)value forKey:(NSString *)key {
    [extraHeaders setObject:value forKey:key];
}
- (ServerBlob *)newServerBlob:(NSError **)error {
    [blobData release];
    blobData = nil;
    if (blob != nil) {
        blobData = [[blob slurp:error] retain];
        if (blobData == nil) {
            return nil;
        }
    }
    NSAutoreleasePool *pool = nil;
    NSTimeInterval sleepTime = INITIAL_RETRY_SLEEP;
    ServerBlob *sb = nil;
    NSError *myError = nil;
    for (;;) {
        [pool drain];
        pool = [[NSAutoreleasePool alloc] init];
        BOOL transientError = NO;
        BOOL needSleep = NO;
        myError = nil;
        sb = [self newServerBlobOnce:&myError];
        if (sb != nil) {
            break;
        }
        if ([myError isSSLError]) {
            HSLogError(@"SSL error: %@", myError);
            [myError logSSLCerts];
        }
        if ([myError isErrorWithDomain:[S3Service errorDomain] code:ERROR_NOT_FOUND]) {
            break;
        } else if ([myError isErrorWithDomain:[S3Service errorDomain] code:ERROR_TEMPORARY_REDIRECT]) {
            NSString *location = [[myError userInfo] objectForKey:@"location"];
            HSLogDebug(@"redirecting %@ to %@", url, location);
            [url release];
            url = [[NSURL alloc] initWithString:location];
            if (url == nil) {
                HSLogError(@"invalid redirect URL %@", location);
                myError = [NSError errorWithDomain:[S3Service errorDomain] code:-1 description:[NSString stringWithFormat:@"invalid redirect URL %@", location]];
                break;
            }
        } else if ([myError isErrorWithDomain:[S3Service errorDomain] code:S3SERVICE_ERROR_AMAZON_ERROR]) {
            int httpStatusCode = [[[myError userInfo] objectForKey:@"HTTPStatusCode"] intValue];
            NSString *amazonCode = [[myError userInfo] objectForKey:@"AmazonCode"];
            
            if (retryOnTransientError && [amazonCode isEqualToString:@"RequestTimeout"]) {
                transientError = YES;
                
            } else if (httpStatusCode == HTTP_INTERNAL_SERVER_ERROR) {
                transientError = YES;
                needSleep = YES;
                
            } else if (retryOnTransientError && httpStatusCode == HTTP_SERVICE_NOT_AVAILABLE) {
                transientError = YES;
                needSleep = YES;
                
            } else {
                HSLogError(@"%@ %@ (blob %@): %@", method, url, blob, myError);
                break;
            }
        } else if ([myError isConnectionResetError]) {
            transientError = YES;
        } else if (retryOnTransientError && [myError isTransientError]) {
            transientError = YES;
            needSleep = YES;
        } else {
            HSLogError(@"%@ %@ (blob %@): %@", method, url, blob, myError);
            break;
        }
        
        if (transientError) {
            HSLogWarn(@"retrying %@ %@ (request body %@): %@", method, url, blob, myError);
        }
        if (needSleep) {
            [NSThread sleepForTimeInterval:sleepTime];
            sleepTime *= RETRY_SLEEP_GROWTH_FACTOR;
            if (sleepTime > MAX_RETRY_SLEEP) {
                sleepTime = MAX_RETRY_SLEEP;
            }
        }
    }
    [myError retain];
    [pool drain];
    [myError autorelease];
    if (error != NULL) { *error = myError; }
    return sb;
}
@end

@implementation S3Request (internal)
- (ServerBlob *)newServerBlobOnce:(NSError **)error {
    id <HTTPConnection> conn = [[[HTTPConnectionFactory theFactory] newHTTPConnectionToURL:url method:method httpTimeoutSetting:httpTimeoutSetting httpConnectionDelegate:httpConnectionDelegate] autorelease];
    if (conn == nil) {
        return nil;
    }
    [conn setRequestHostHeader];
    [conn setRFC822DateRequestHeader];
    if (blob != nil) {
        if ([blob mimeType] != nil) {
            [conn setRequestHeader:[blob mimeType] forKey:@"Content-Type"];
        }
        if ([blob downloadName] != nil) {
            [conn setRequestContentDispositionHeader:[blob downloadName]];
        }
        [conn setRequestHeader:[NSString stringWithFormat:@"%qu", length] forKey:@"Content-Length"];
    }
    for (NSString *headerKey in [extraHeaders allKeys]) {
        [conn setRequestHeader:[extraHeaders objectForKey:headerKey] forKey:headerKey];
    }
    if (![sap setAuthorizationRequestHeaderOnHTTPConnection:conn error:error]) {
        return nil;
    }
    bytesUploaded = 0;
    
    HSLogDebug(@"%@ %@", method, url);
    
    BOOL execRet = [conn executeRequestWithBody:blobData error:error];
    if (!execRet) {
        HSLogDebug(@"executeRequestWithBody failed");
        return nil;
    }
    ServerBlob *ret = nil;
    id <InputStream> bodyStream = [conn newResponseBodyStream:error];
    if (bodyStream == nil) {
        HSLogDebug(@"newResponseBodyStream failed");
        return nil;
    }
    NSData *response = [bodyStream slurp:error];
    [bodyStream release];
    if (response == nil) {
        return nil;
    }
    int code = [conn responseCode];
    if (code >= 200 && code <= 299) {
        ret = [[ServerBlob alloc] initWithData:response mimeType:[conn responseContentType] downloadName:[conn responseDownloadName]];
        HSLogDebug(@"HTTP %d; returning response length=%d", code, [response length]);
        return ret;
    }
    
    HSLogTrace(@"http response body: %@", [[[NSString alloc] initWithBytes:[response bytes] length:[response length] encoding:NSUTF8StringEncoding] autorelease]);
    if (code == HTTP_NOT_FOUND) {
        SETNSERROR([S3Service errorDomain], ERROR_NOT_FOUND, @"%@ not found", url);
        HSLogDebug(@"returning not-found error");
        return nil;
    }
    if (code == HTTP_METHOD_NOT_ALLOWED) {
        HSLogError(@"%@ 405 error", url);
        SETNSERROR([S3Service errorDomain], ERROR_RRS_NOT_FOUND, @"%@ 405 error", url);
    }
    if (code == HTTP_MOVED_TEMPORARILY) {
        NSString *location = [conn responseHeaderForKey:@"Location"];
        NSDictionary *userInfo = [NSDictionary dictionaryWithObject:location forKey:@"location"];
        NSError *myError = [NSError errorWithDomain:[S3Service errorDomain] code:ERROR_TEMPORARY_REDIRECT userInfo:userInfo];
        if (error != NULL) {
            *error = myError;
        }
        HSLogDebug(@"returning moved-temporarily error");
        return nil;
    }
    
    NSError *myError = [NSError amazonErrorWithHTTPStatusCode:code responseBody:response];
    HSLogDebug(@"%@ %@ error: %@", method, conn, myError);
    if (error != NULL) {
        *error = myError;
    }
    return nil;
}
@end
