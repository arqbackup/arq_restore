/*
 Copyright (c) 2009-2010, Stefan Reitshamer http://www.haystacksoftware.com
 
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
#import "HTTPConnection.h"
#import "HTTPConnection_S3.h"
#import "ServerBlob.h"
#import "S3Service.h"
#import "NSXMLNode_extra.h"
#import "SetNSError.h"
#import "CFStreamPair.h"
#import "RegexKitLite.h"
#import "NSErrorCodes.h"
#import "MonitoredInputStream.h"
#import "NSError_extra.h"

#define INITIAL_RETRY_SLEEP (0.5)
#define RETRY_SLEEP_GROWTH_FACTOR (1.5)
#define MAX_RETRY_SLEEP (5.0)

@interface S3Request (internal)
- (ServerBlob *)newServerBlobOnce:(NSError **)error;
- (BOOL)setError:(NSError **)error withHTTPResponseCode:(int)code responseData:(NSData *)response;
@end

@implementation S3Request
- (id)initWithMethod:(NSString *)theMethod path:(NSString *)thePath queryString:(NSString *)theQueryString authorizationProvider:(S3AuthorizationProvider *)theSAP useSSL:(BOOL)ssl retryOnNetworkError:(BOOL)retry {
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
        retryOnNetworkError = retry;
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
    [virtualHost release];
    [virtualPath release];
    [extraHeaders release];
    [delegate release];
    [super dealloc];
}
- (void)setDelegate:(id)theDelegate {
    if (delegate != theDelegate) {
        [delegate release];
        delegate = [theDelegate retain];
    }
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
            SETNSERROR([S3Service errorDomain], -1, @"invalid path-style path -- missing s3 bucket name");
            return nil;
        }
        NSRange pathRange = [path rangeOfRegex:pattern capture:2];
        if (pathRange.location == NSNotFound) {
            SETNSERROR([S3Service errorDomain], -1, @"invalid path-style path -- missing path");
            return nil;
        }
        virtualHost = [[[path substringWithRange:s3BucketRange] stringByAppendingString:@".s3.amazonaws.com"] retain];
        virtualPath = [[path substringWithRange:pathRange] retain];
    }
    NSAutoreleasePool *pool = nil;
    NSTimeInterval sleepTime = INITIAL_RETRY_SLEEP;
    ServerBlob *sb = nil;
    NSError *myError = nil;
    for (;;) {
        [pool drain];
        pool = [[NSAutoreleasePool alloc] init];
        myError = nil;
        sb = [self newServerBlobOnce:&myError];
        [myError retain];
        [myError autorelease];
        if (sb != nil) {
            break;
        }
        BOOL needSleep = NO;
        if ([[myError domain] isEqualToString:[S3Service amazonErrorDomain]]) {
            NSString *amazonErrorCode = [[myError userInfo] objectForKey:@"Code"];
            if ([myError code] == HTTP_INTERNAL_SERVER_ERROR) {
                HSLogInfo(@"S3 returned %u; retrying", HTTP_INTERNAL_SERVER_ERROR);
                needSleep = YES;
            } else if ([myError code] == HTTP_BAD_REQUEST && [amazonErrorCode isEqualToString:@"RequestTimeout"]) {
                HSLogInfo(@"s3 RequestTimeout; retrying");
            } else if ([myError code] == HTTP_SERVICE_NOT_AVAILABLE) {
                HSLogInfo(@"S3 returned @u; retrying", HTTP_SERVICE_NOT_AVAILABLE);
                needSleep = YES;
            } else if ([myError code] == HTTP_MOVED_TEMPORARILY) {
                [virtualHost release];
                virtualHost = [[[myError userInfo] objectForKey:@"Endpoint"] copy];
                HSLogDebug(@"S3 redirect to %@", virtualHost);
            } else {
                if ([myError code] != HTTP_NOT_FOUND) {
                    HSLogError(@"error getting %@: %@", virtualPath, [myError localizedDescription]);
                }
                break;
            }
        } else if ([myError isErrorWithDomain:@"UnixErrorDomain" code:ETIMEDOUT]) {
            HSLogDebug(@"timeout error (retrying): %@", [myError description]);
            needSleep = YES;
        } else if ([[myError domain] isEqualToString:[CFStreamPair errorDomain]] && retryOnNetworkError) {
            HSLogDebug(@"network error (retrying): %@", [myError localizedDescription]);
            needSleep = YES;
        } else {
            break;
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
    if (sb == nil && error != NULL) {
        NSAssert(myError != nil, @"myError must be set");
        *error = myError;
    }
    return sb;
}
@end

@implementation S3Request (internal)
- (ServerBlob *)newServerBlobOnce:(NSError **)error {
    HTTPConnection *conn = [[[HTTPConnection alloc] initWithHost:virtualHost useSSL:withSSL error:error] autorelease];
    if (conn == nil) {
        return nil;
    }
    [conn setRequestMethod:method pathInfo:[virtualPath stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding] queryString:queryString protocol:HTTP_1_1];
    [conn setRequestHostHeader];
    [conn setRFC822DateRequestHeader];
    [conn setRequestKeepAliveHeader];
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
    [conn setAuthorizationRequestHeaderUsingProvider:sap s3BucketName:s3BucketName];
    id <InputStream> requestBody = nil;
    if (blob != nil) {
        requestBody = [[[blob inputStreamFactory] newInputStream] autorelease];
        if (delegate != nil) {
            requestBody = [[[MonitoredInputStream alloc] initWithUnderlyingStream:requestBody delegate:self] autorelease];
        }
        bytesUploaded = 0;
    }
    BOOL execRet = [conn executeRequestWithBody:requestBody error:error];
    if (!execRet) {
        return nil;
    }
    ServerBlob *ret = nil;
    int code = [conn responseCode];
    if (code >= 200 && code <= 299) {
        id <InputStream> bodyStream = [conn newResponseBodyStream:error];
        if (bodyStream == nil) {
            return nil;
        }
        ret = [[ServerBlob alloc] initWithInputStream:bodyStream mimeType:[conn responseMimeType] downloadName:[conn responseDownloadName]];
        [bodyStream release];
        return ret;
    }
    
    if ([delegate respondsToSelector:@selector(s3Request:bytesFailedToUpload:)]) {
        [delegate s3Request:self bytesFailedToUpload:bytesUploaded];
    }
    if (code >= 400 && code != HTTP_NOT_FOUND) {
        HSLogDebug(@"S3 HTTP response code was %d; requesting close on connection", code);
        [conn setCloseRequested];
    }
    NSData *response = [conn slurpResponseBody:error];
    if (response == nil) {
        return nil;
    }
    
    if (code == HTTP_NOT_FOUND) {
        SETNSERROR([S3Service errorDomain], ERROR_NOT_FOUND, @"%@ not found", path);
        return nil;
    }
    
    NSError *amazonError = nil;
    [self setError:&amazonError withHTTPResponseCode:code responseData:response];
    HSLogError(@"S3 error: %@", [amazonError description]);
    if (error != NULL) {
        *error = amazonError;
    }
    return nil;
}
- (BOOL)setError:(NSError **)error withHTTPResponseCode:(int)code responseData:(NSData *)response {
    NSAssert(error != NULL, @"NSError **error must not be NULL");
    NSString *errorXML = [[[NSString alloc] initWithData:response encoding:NSUTF8StringEncoding] autorelease];
    HSLogDebug(@"amazon HTTP error code=%d; xml=%@", code, errorXML);
    NSError *xmlError = nil;
    NSXMLDocument *xmlDoc = [[[NSXMLDocument alloc] initWithData:response options:0 error:&xmlError] autorelease];
    if (xmlDoc == nil) {
        HSLogError(@"error parsing Amazon error XML: %@", [xmlError localizedDescription]);
        SETNSERROR([S3Service errorDomain], code, @"Amazon error (failed to parse XML); xml=%@", errorXML);
        return YES;
    }
    
    HSLogTrace(@"error XML: %@", [xmlDoc description]);
    NSXMLElement *rootElement = [xmlDoc rootElement];
    NSArray *errorNodes = [rootElement nodesForXPath:@"//Error" error:&xmlError];
    
    if (errorNodes == nil) {
        HSLogError(@"error finding Error node in Amazon error XML: %@", [xmlError localizedDescription]);
        SETNSERROR([S3Service errorDomain], code, @"Amazon error (failed to parse Error node in XML); xml=%@", errorXML);
        return YES;
    }
    
    if ([errorNodes count] == 0) {
        HSLogWarn(@"missing Error node in S3 XML response %@", errorXML);
        SETNSERROR([S3Service errorDomain], code, @"Amazon error (no Error node found); xml=%@", errorXML);
        return YES;
    }
    
    if ([errorNodes count] > 1) {
        HSLogWarn(@"ignoring additional S3 errors");
    }
    NSXMLNode *errorNode = [errorNodes objectAtIndex:0];
    NSString *errorCode = [[errorNode childNodeNamed:@"Code"] stringValue];
    NSString *errorMessage = [[errorNode childNodeNamed:@"Message"] stringValue];
    NSString *endpoint = (code == HTTP_MOVED_TEMPORARILY) ? [[errorNode childNodeNamed:@"Endpoint"] stringValue] : nil;
    NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                              (errorCode != nil ? errorCode : @""), @"Code",
                              (errorMessage != nil ? errorMessage : @""), @"Message",
                              (errorMessage != nil ? errorMessage : @""), NSLocalizedDescriptionKey,
                              (endpoint != nil ? endpoint : @""), @"Endpoint",
                              nil];
    NSError *myError = [NSError errorWithDomain:[S3Service amazonErrorDomain] code:code userInfo:userInfo];
    *error = myError;
    return YES;
}

#pragma mark MonitoredInputStream
- (BOOL)monitoredInputStream:(MonitoredInputStream *)stream receivedBytes:(unsigned long long)theLength error:(NSError **)error {
    bytesUploaded += theLength;
    if (delegate != nil && ![delegate s3Request:self willUploadBytes:theLength error:error]) {
        return NO;
    }
    return YES;
}
@end
