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


#define INITIAL_RETRY_SLEEP (0.5)
#define RETRY_SLEEP_GROWTH_FACTOR (1.5)
#define MAX_RETRY_SLEEP (5.0)

@interface S3Request (internal)
- (ServerBlob *)newServerBlobOnce:(NSError **)error;
@end

@implementation S3Request
- (id)initWithMethod:(NSString *)theMethod path:(NSString *)thePath queryString:(NSString *)theQueryString authorizationProvider:(S3AuthorizationProvider *)theSAP useSSL:(BOOL)ssl retryOnTransientError:(BOOL)retry {
    return [self initWithMethod:theMethod path:thePath queryString:theQueryString authorizationProvider:theSAP useSSL:ssl retryOnTransientError:retry urlConnectionDelegate:nil];
}
- (id)initWithMethod:(NSString *)theMethod path:(NSString *)thePath queryString:(NSString *)theQueryString authorizationProvider:(S3AuthorizationProvider *)theSAP useSSL:(BOOL)ssl retryOnTransientError:(BOOL)retry urlConnectionDelegate:(id)theURLConnectionDelegate {
    if (self = [super init]) {
        method = [theMethod copy];
        path = [thePath copy];
        NSRange s3BucketNameRange = [path rangeOfRegex:@"^/([^/]+)" capture:1];
        if (s3BucketNameRange.location != NSNotFound) {
            s3BucketName = [path substringWithRange:s3BucketNameRange];
        }
        queryString = [theQueryString copy];
        sap = [theSAP retain];
        withSSL = ssl;
        retryOnTransientError = retry;
        urlConnectionDelegate = theURLConnectionDelegate; // Don't retain it.
        extraHeaders = [[NSMutableDictionary alloc] init];
    }
    return self;
}
- (void)dealloc {
    [method release];
    [path release];
    [queryString release];
    [sap release];
    [blob release];
    [blobData release];
    [virtualHost release];
    [virtualPath release];
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
    [virtualHost release];
    virtualHost = nil;
    [virtualPath release];
    virtualPath = nil;
    if ([path isEqualToString:@"/"]) {
        // List-bucket request.
        virtualHost = [@"s3.amazonaws.com" retain];
        virtualPath = [path retain];
    } else {
        NSString *pattern = @"^/([^/]+)(.+)$";
        NSRange s3BucketRange = [path rangeOfRegex:pattern capture:1];
        if (s3BucketRange.location == NSNotFound) {
            SETNSERROR([S3Service errorDomain], S3SERVICE_INVALID_PARAMETERS, @"invalid path-style path -- missing s3 bucket name");
            return nil;
        }
        NSRange pathRange = [path rangeOfRegex:pattern capture:2];
        if (pathRange.location == NSNotFound) {
            SETNSERROR([S3Service errorDomain], S3SERVICE_INVALID_PARAMETERS, @"invalid path-style path -- missing path");
            return nil;
        }
        virtualHost = [[[path substringWithRange:s3BucketRange] stringByAppendingString:@".s3.amazonaws.com"] retain];
        virtualPath = [[path substringWithRange:pathRange] retain];
    }
    
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
    BOOL loggedRetry = NO;
    for (;;) {
        [pool drain];
        pool = [[NSAutoreleasePool alloc] init];
        BOOL transientError = NO;
        BOOL needSleep = NO;
        myError = nil;
        sb = [self newServerBlobOnce:&myError];
        if (sb != nil) {
            break;
        } else if ([myError isErrorWithDomain:[S3Service errorDomain] code:ERROR_NOT_FOUND]) {
            break;
        } else if ([myError isErrorWithDomain:[S3Service errorDomain] code:S3SERVICE_ERROR_AMAZON_ERROR]) {
            int httpStatusCode = [[[myError userInfo] objectForKey:@"HTTPStatusCode"] intValue];
            NSString *amazonCode = [[myError userInfo] objectForKey:@"AmazonCode"];
            
            if (httpStatusCode == HTTP_MOVED_TEMPORARILY) {
                [virtualHost release];
                virtualHost = [[[myError userInfo] objectForKey:@"AmazonEndpoint"] copy];
                HSLogInfo(@"S3 redirect to %@", virtualHost);
                
            } else if (retryOnTransientError && [amazonCode isEqualToString:@"RequestTimeout"]) {
                transientError = YES;
                
            } else if (httpStatusCode == HTTP_INTERNAL_SERVER_ERROR) {
                transientError = YES;
                needSleep = YES;
                
            } else if (retryOnTransientError && httpStatusCode == HTTP_SERVICE_NOT_AVAILABLE) {
                transientError = YES;
                needSleep = YES;
                
            } else {
                HSLogError(@"%@ %@ (blob %@): %@", method, virtualPath, blob, myError);
                break;
            }
            
        } else if (retryOnTransientError && [myError isTransientError]) {
            transientError = YES;
            needSleep = YES;

        } else {
            HSLogError(@"%@ %@ (blob %@): %@", method, virtualPath, blob, myError);
            break;
        }
        
        if (transientError) {
            if (!loggedRetry) {
                HSLogWarn(@"retrying %@ %@ (request body %@): %@", method, virtualPath, blob, myError);
                loggedRetry = YES;

            } else {
                HSLogDebug(@"retrying %@ %@ (request body %@): %@", method, virtualPath, blob, myError);
            }
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
    NSString *urlString = [NSString stringWithFormat:@"http%@://%@%@", (withSSL ? @"s" : @""), virtualHost, [virtualPath stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    if (queryString) {
        urlString = [urlString stringByAppendingString:queryString];
    }
    id <HTTPConnection> conn = [[[URLConnection alloc] initWithURL:[NSURL URLWithString:urlString] method:method delegate:urlConnectionDelegate] autorelease];
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
    if (![sap setAuthorizationRequestHeaderOnHTTPConnection:conn usingS3BucketName:s3BucketName error:error]) {
        return nil;
    }
    bytesUploaded = 0;
    BOOL execRet = [conn executeRequestWithBody:blobData error:error];
    if (!execRet) {
        return nil;
    }
    ServerBlob *ret = nil;
    id <InputStream> bodyStream = [conn newResponseBodyStream:error];
    if (bodyStream == nil) {
        return nil;
    }
    int code = [conn responseCode];
    
    if (code >= 200 && code <= 299) {
        ret = [[ServerBlob alloc] initWithInputStream:bodyStream mimeType:[conn responseContentType] downloadName:[conn responseDownloadName]];
        [bodyStream release];
        return ret;
    }
    
    NSData *response = [bodyStream slurp:error];
    if (response == nil) {
        return nil;
    }
    
    if (code == HTTP_NOT_FOUND) {
        SETNSERROR([S3Service errorDomain], ERROR_NOT_FOUND, @"%@ not found", path);
        return nil;
    }
    
    NSError *myError = [NSError amazonErrorWithHTTPStatusCode:code responseBody:response];
    HSLogDebug(@"%@ %@: %@", method, conn, myError);
    if (error != NULL) {
        *error = myError;
    }
    return nil;
}
@end
