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

#import "CFHTTPConnection.h"
#import "BufferedInputStream.h"
#import "HSLog.h"
#import "OutputStream.h"
#import "RFC2616DateFormatter.h"
#import "RegexKitLite.h"
#import "HTTP.h"
#import "SetNSError.h"
#import "ChunkedInputStream.h"
#import "FixedLengthInputStream.h"
#import "NSData-InputStream.h"
#import "DataInputStream.h"
#import "CFNetwork.h"
#import <SystemConfiguration/SystemConfiguration.h>
#import "CFNetwork.h"
#import "InputStreams.h"
#import "CFHTTPInputStream.h"
#import "NSErrorCodes.h"
#import "HTTPConnectionDelegate.h"
#import "HTTPTimeoutSetting.h"


#define DEFAULT_TIMEOUT_SECONDS (30.0)
#define MY_BUF_SIZE (8192)
static NSString *runLoopMode = @"HTTPConnectionRunLoopMode";

@interface CFHTTPConnection (usability)
- (BOOL)isUsable;
@end

@interface CFHTTPConnection (internal)
- (void)doExecuteRequestWithBody:(NSData *)requestBody;
- (void)setProxiesOnReadStream;
- (void)handleNetworkEvent:(CFStreamEventType)theType;
- (void)handleBytesAvailable;
- (void)handleStreamComplete;
- (void)handleStreamError;
- (void)readResponseHeaders;
- (void)destroyReadStream;
- (void)resetSendTimeout;
- (id <InputStream>)doNewResponseBodyStream:(NSError **)error;
- (NSInteger)doRead:(unsigned char *)buf bufferLength:(NSUInteger)length error:(NSError **)error;
@end

@interface CFHTTPConnection (callback)
- (void)sentRequestBytes:(NSInteger)count;
@end


static void ReadStreamClientCallback(CFReadStreamRef readStream, CFStreamEventType type, void *clientCallBackInfo) {
    [(CFHTTPConnection *)clientCallBackInfo handleNetworkEvent:type];
}

@implementation CFHTTPConnection
+ (NSString *)errorDomain {
    return @"HTTPConnectionErrorDomain";
}

- (id)initWithURL:(NSURL *)theURL method:(NSString *)theMethod httpTimeoutSetting:(HTTPTimeoutSetting *)theHTTPTimeoutSetting httpConnectionDelegate:(id <HTTPConnectionDelegate>)theDelegate {
    return [self initWithURL:theURL method:theMethod httpTimeoutSetting:theHTTPTimeoutSetting httpConnectionDelegate:theDelegate previousConnection:nil];
}
- (id)initWithURL:(NSURL *)theURL method:(NSString *)theMethod httpTimeoutSetting:(HTTPTimeoutSetting *)theHTTPTimeoutSetting httpConnectionDelegate:(id <HTTPConnectionDelegate>)theDelegate previousConnection:(CFHTTPConnection *)thePrevious {
    if (self = [super init]) {
        dateFormatter = [[RFC2616DateFormatter alloc] init];
        url = [theURL retain];
        requestMethod = [theMethod retain];
        httpTimeoutSetting = [theHTTPTimeoutSetting retain];
        httpConnectionDelegate = theDelegate;
        requestHeaders = [[NSMutableDictionary alloc] init];
        if (thePrevious != nil) {
            previous = [thePrevious retain];
            createTime = [thePrevious createTime];
        } else {
            createTime = [NSDate timeIntervalSinceReferenceDate];
        }
    }
    return self;
}
- (void)dealloc {
    [dateFormatter release];
    [url release];
    [requestMethod release];
    [httpTimeoutSetting release];
    [requestHeaders release];
    if (request) {
        CFRelease(request);
    }
    [runLoopMode release];
    [responseHeaders release];
    [self destroyReadStream];
    [previous release];
    [sendTimeout release];
    [super dealloc];
}

- (NSString *)errorDomain {
    return @"HTTPConnectionErrorDomain";
}

- (void)setRequestHeader:(NSString *)value forKey:(NSString *)key {
    [requestHeaders setObject:value forKey:key];
}
- (void)setRequestHostHeader {
    [self setRequestHeader:[url host] forKey:@"Host"];
}
- (void)setRequestContentDispositionHeader:(NSString *)downloadName {
    if (downloadName != nil) {
        NSString *encodedFilename = [NSString stringWithFormat:@"\"%@\"", [downloadName stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\\\""]];
        encodedFilename = [encodedFilename stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"];
        NSString *contentDisposition = [NSString stringWithFormat:@"attachment;filename=%@", encodedFilename];
        [self setRequestHeader:contentDisposition forKey:@"Content-Disposition"];
    }
}
- (void)setRFC822DateRequestHeader {
    [self setRequestHeader:[dateFormatter rfc2616StringFromDate:[NSDate date]] forKey:@"Date"];
}
- (NSString *)requestMethod {
    return requestMethod;
}
//- (NSString *)requestPathInfo {
//    return [[url path] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
//}
- (NSString *)requestPathInfo {
    NSString *urlDescription = [url description];
    NSRange rangeBeforeQueryString = [urlDescription rangeOfRegex:@"^([^?]+)"];
    NSString *stringBeforeQueryString = [urlDescription substringWithRange:rangeBeforeQueryString];
    NSString *path = [url path];
    if ([stringBeforeQueryString hasSuffix:@"/"] && ![path hasSuffix:@"/"]) {
        // NSURL's path method strips trailing slashes. Add it back in.
        path = [path stringByAppendingString:@"/"];
    }
    return [path stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
}
- (NSString *)requestQueryString {
    return [url query];
}
- (NSArray *)requestHeaderKeys {
    return [requestHeaders allKeys];
}
- (NSString *)requestHeaderForKey:(NSString *)theKey {
    return [requestHeaders objectForKey:theKey];
}
- (BOOL)executeRequest:(NSError **)error {
    return [self executeRequestWithBody:nil error:error];
}
- (BOOL)executeRequestWithBody:(NSData *)requestBody error:(NSError **)error {
    if (closeRequested) {
        SETNSERROR([CFHTTPConnection errorDomain], -1, @"close was requested; can't reuse this connection");
        return NO;
    }
    [self doExecuteRequestWithBody:requestBody];
    if (errorOccurred) {
        if (error != NULL) {
            *error = _error;
        }
        if ([httpConnectionDelegate respondsToSelector:@selector(httpConnection:subtractSentBytes:)]) {
            [httpConnectionDelegate httpConnection:self subtractSentBytes:totalSent];
        }
        return NO;
    }
    return YES;
}
- (int)responseCode {
    if (responseHeaders == nil) {
        // User probably canceled before we received the response header.
        return HTTP_INTERNAL_SERVER_ERROR;
    }
    return responseStatusCode;
}
- (NSString *)responseHeaderForKey:(NSString *)key {
    return [responseHeaders objectForKey:key];
}
- (NSString *)responseContentType {
    return [self responseHeaderForKey:@"Content-Type"];
}
- (NSString *)responseDownloadName {
    NSString *downloadName = nil;
    NSString *contentDisposition = [self responseHeaderForKey:@"Content-Disposition"];
    if (contentDisposition != nil) {
        NSRange filenameRange = [contentDisposition rangeOfRegex:@"attachment;filename=(.+)" capture:1];
        if (filenameRange.location != NSNotFound) {
            downloadName = [contentDisposition substringWithRange:filenameRange];
        }
    }
    return downloadName;
}
- (id <InputStream>)newResponseBodyStream:(NSError **)error {
    id <InputStream> ret = [self doNewResponseBodyStream:error];
    if (ret == nil && [httpConnectionDelegate respondsToSelector:@selector(httpConnection:subtractSentBytes:)]) {
        [httpConnectionDelegate httpConnection:self subtractSentBytes:totalSent];
    }
    return ret;
}
- (void)setCloseRequested {
    closeRequested = YES;
}
- (BOOL)isCloseRequested {
    return closeRequested || errorOccurred;
}
- (NSTimeInterval)createTime {
    return createTime;
}
- (void)releasePreviousConnection {
    [previous release];
    previous = nil;
}

#pragma mark InputStream
- (NSInteger)read:(unsigned char *)buf bufferLength:(NSUInteger)length error:(NSError **)error {
    NSInteger ret = [self doRead:buf bufferLength:length error:error];
    if (ret < 0 && [httpConnectionDelegate respondsToSelector:@selector(httpConnection:subtractSentBytes:)]) {
        [httpConnectionDelegate httpConnection:self subtractSentBytes:totalSent];
    }
    return ret;
}
- (NSData *)slurp:(NSError **)error {
    return [InputStreams slurp:self error:error];
}

#pragma mark NSObject
- (NSString *)description {
    return [NSString stringWithFormat:@"<HTTPConnection url=%@ method=%@>", url, requestMethod];
}
@end

@implementation CFHTTPConnection (internal)
- (void)doExecuteRequestWithBody:(NSData *)requestBody {
    request = CFHTTPMessageCreateRequest(kCFAllocatorDefault, (CFStringRef)requestMethod, (CFURLRef)url, kCFHTTPVersion1_1);
    if (!request) {
        errorOccurred = YES;
        _error = [[NSError errorWithDomain:[CFNetwork errorDomain] code:-1 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"Error creating request", NSLocalizedDescriptionKey, nil]] retain];
        return;
    }
    
    // Add headers.
    for (NSString *header in [requestHeaders allKeys]) {
        CFHTTPMessageSetHeaderFieldValue(request, (CFStringRef)header, (CFStringRef)[requestHeaders objectForKey:header]);
    }
    
    // Add keep-alive header every time:
    CFHTTPMessageSetHeaderFieldValue(request, CFSTR("Connection"), CFSTR("Keep-Alive"));
    
    if ([requestBody length] > 0) {
        CFHTTPInputStream *bodyStream = [[[CFHTTPInputStream alloc] initWithCFHTTPConnection:self data:requestBody httpConnectionDelegate:httpConnectionDelegate] autorelease];
        readStream = (NSInputStream *)CFReadStreamCreateForStreamedHTTPRequest(kCFAllocatorDefault, request, (CFReadStreamRef)bodyStream);
    } else {
        readStream = (NSInputStream *)CFReadStreamCreateForHTTPRequest(kCFAllocatorDefault, request);
    }
    
    HSLogTrace(@"new readStream: %p", readStream);
    if (!readStream) {
        errorOccurred = YES;
        _error = [[NSError errorWithDomain:[CFNetwork errorDomain] code:-1 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"Error creating read stream", NSLocalizedDescriptionKey, nil]] retain];
        return;
    }
    
    if ([[[url scheme] lowercaseString] isEqualToString:@"https"]) {
        NSMutableDictionary *sslProperties = [NSDictionary dictionaryWithObjectsAndKeys:
                                              (NSString *)kCFStreamSocketSecurityLevelNegotiatedSSL, kCFStreamSSLLevel,
                                              kCFBooleanTrue, kCFStreamSSLAllowsExpiredCertificates,
                                              kCFBooleanTrue, kCFStreamSSLAllowsExpiredRoots,
                                              kCFBooleanTrue, kCFStreamSSLAllowsAnyRoot,
                                              kCFBooleanFalse, kCFStreamSSLValidatesCertificateChain,
                                              kCFNull, kCFStreamSSLPeerName,
                                              nil];
        CFReadStreamSetProperty((CFReadStreamRef)readStream, kCFStreamPropertySSLSettings, sslProperties);
    }
    [self setProxiesOnReadStream];
    
    // Attempt to reuse this connection.
    CFReadStreamSetProperty((CFReadStreamRef)readStream, kCFStreamPropertyHTTPAttemptPersistentConnection, kCFBooleanTrue);
    
    CFStreamClientContext ctxt = { 0, self, NULL, NULL, NULL };
    CFReadStreamSetClient((CFReadStreamRef)readStream, kCFStreamEventHasBytesAvailable | kCFStreamEventEndEncountered | kCFStreamEventErrorOccurred, ReadStreamClientCallback, &ctxt);
    [readStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:runLoopMode];
    if (!CFReadStreamOpen((CFReadStreamRef)readStream)) {
        errorOccurred = YES;
        _error = [[NSError errorWithDomain:[CFNetwork errorDomain] code:-1 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"Error opening read stream", NSLocalizedDescriptionKey, nil]] retain];
        return;
    }
    [previous releasePreviousConnection];
}
- (void)setProxiesOnReadStream {
    NSDictionary *proxySettings = (NSDictionary *)SCDynamicStoreCopyProxies(NULL);
    NSArray *proxies = (NSArray *)CFNetworkCopyProxiesForURL((CFURLRef)url, (CFDictionaryRef)proxySettings);
    if ([proxies count] > 0) {
        NSDictionary *proxy = [proxies objectAtIndex:0];
        NSString *proxyType = [proxy objectForKey:(NSString *)kCFProxyTypeKey];
        if (![proxyType isEqualToString:(NSString *)kCFProxyTypeNone]) {
            NSString *proxyHost = [proxy objectForKey:(NSString *)kCFProxyHostNameKey];
            int proxyPort = [[proxy objectForKey:(NSString *)kCFProxyPortNumberKey] intValue];
            NSString *hostKey;
            NSString *portKey;
            if ([proxyType isEqualToString:(NSString *)kCFProxyTypeSOCKS]) {
                hostKey = (NSString *)kCFStreamPropertySOCKSProxyHost;
                portKey = (NSString *)kCFStreamPropertySOCKSProxyPort;
            } else {
                hostKey = (NSString *)kCFStreamPropertyHTTPProxyHost;
                portKey = (NSString *)kCFStreamPropertyHTTPProxyPort;
                if ([[[url scheme] lowercaseString] isEqualToString:@"https"]) {
                    hostKey = (NSString *)kCFStreamPropertyHTTPSProxyHost;
                    portKey = (NSString *)kCFStreamPropertyHTTPSProxyPort;
                }
            }
            // FIXME: Support proxy autconfiguration files (kCFProxyTypeAutoConfigurationURL) too!
            NSDictionary *proxyToUse = [NSDictionary dictionaryWithObjectsAndKeys:
                                        proxyHost, hostKey,
                                        [NSNumber numberWithInt:proxyPort], portKey,
                                        nil];
            if ([proxyType isEqualToString:(NSString *)kCFProxyTypeSOCKS]) {
                CFReadStreamSetProperty((CFReadStreamRef)readStream, kCFStreamPropertySOCKSProxy, proxyToUse);
            } else {
                CFReadStreamSetProperty((CFReadStreamRef)readStream, kCFStreamPropertyHTTPProxy, proxyToUse);
            }
        }
    }
    [proxies release];
    [proxySettings release];
}    
- (void)handleNetworkEvent:(CFStreamEventType)theType {
    switch (theType) {
        case kCFStreamEventHasBytesAvailable:
            [self handleBytesAvailable];
            break;
        case kCFStreamEventEndEncountered:
            [self handleStreamComplete];
            break;
        case kCFStreamEventErrorOccurred:
            [self handleStreamError];
            break;
        default:
            break;
    }
}
- (void)handleBytesAvailable {
    HSLogTrace(@"%@: handleBytesAvailable", self);
    [self readResponseHeaders];
    
    // Rarely, there aren't any data actually available.
    if (!CFReadStreamHasBytesAvailable((CFReadStreamRef)readStream)) {
        return;
    }
    hasBytesAvailable = YES;
}
- (void)handleStreamComplete {
    HSLogTrace(@"%@: handleStreamComplete", self);
    [self readResponseHeaders];
    complete = YES;
}
- (void)handleStreamError {
    HSLogTrace(@"%@: handleStreamError", self);
    if (errorOccurred) {
        NSLog(@"already have an error!");
        return;
    }
    errorOccurred = YES;
    _error = (NSError *)CFReadStreamCopyError((CFReadStreamRef)readStream);
    complete = YES;
    closeRequested = YES;
}
- (void)readResponseHeaders {
    if (responseHeaders) {
        return;
    }
    CFHTTPMessageRef message = (CFHTTPMessageRef)CFReadStreamCopyProperty((CFReadStreamRef)readStream, kCFStreamPropertyHTTPResponseHeader);
    if (message) {
        if (!CFHTTPMessageIsHeaderComplete(message)) {
            HSLogDebug(@"%@: header not complete!", self);
        } else {
            [responseHeaders release];
            responseHeaders = (NSDictionary *)CFHTTPMessageCopyAllHeaderFields(message);
            responseStatusCode = (int)CFHTTPMessageGetResponseStatusCode(message);
        }
        CFRelease(message);
    }
}
- (void)destroyReadStream {
    if (readStream != nil) {
        HSLogTrace(@"destroying readStream: %p", readStream);
        CFReadStreamSetClient((CFReadStreamRef)readStream, kCFStreamEventNone, NULL, NULL);
        [readStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:runLoopMode];
        [readStream close];
        [readStream release];
        readStream = nil;
    }
}
- (void)resetSendTimeout {
    NSTimeInterval timeoutSeconds = [httpTimeoutSetting timeoutSeconds];
    if (timeoutSeconds == 0) {
        timeoutSeconds = DEFAULT_TIMEOUT_SECONDS;
    }
    [sendTimeout release];
    sendTimeout = [[[NSDate date] addTimeInterval:timeoutSeconds] retain];
}    
- (id <InputStream>)doNewResponseBodyStream:(NSError **)error {
    while (!complete && !hasBytesAvailable) {
        [self resetSendTimeout];
        HSLogTrace(@"newResponseBodyStream: running the runloop until %f", [sendTimeout timeIntervalSinceReferenceDate]);
        [[NSRunLoop currentRunLoop] runMode:runLoopMode beforeDate:sendTimeout];
        NSTimeInterval current = [NSDate timeIntervalSinceReferenceDate];
        if ((current + 0.1) > [sendTimeout timeIntervalSinceReferenceDate]) {
            HSLogWarn(@"timeout waiting for response to %@ %@", requestMethod, url);
            SETNSERROR([self errorDomain], ERROR_TIMEOUT, @"timeout while attempting to send HTTP request");
            closeRequested = YES;
            return nil;
        } else {
            HSLogTrace(@"current time %f is not later than timeout %f; continuing", current, [sendTimeout timeIntervalSinceReferenceDate]);
        }
    }
    if (errorOccurred) {
        if ([httpConnectionDelegate abortRequestedForHTTPConnection:self]) {
            [_error release];
            _error = [[NSError alloc] initWithDomain:[self errorDomain] code:ERROR_ABORT_REQUESTED userInfo:[NSDictionary dictionaryWithObject:@"abort requested" forKey:NSLocalizedDescriptionKey]];
        }
        if (error != NULL) {
            *error = _error;
        }
        return nil;
    }
    hasBytesAvailable = NO;
    id <InputStream> ret = nil;
    if (complete) {
        HSLogTrace(@"%@: empty response body", self);
        ret = [[NSData data] newInputStream];
    } else {    
        NSAssert(responseHeaders != nil, @"responseHeaders can't be nil");
        
        NSString *transferEncoding = [self responseHeaderForKey:@"Transfer-Encoding"];
        //        NSString *contentLength = [self responseHeaderForKey:@"Content-Length"];
        HSLogTrace(@"Content-Length = %@", [self responseHeaderForKey:@"Content-Length"]);
        HSLogTrace(@"Transfer-Encoding = %@", transferEncoding);
        if (transferEncoding != nil && ![transferEncoding isEqualToString:@"Identity"]) {
            if ([[transferEncoding lowercaseString] isEqualToString:@"chunked"]) {
                HSLogTrace(@"%@: chunked response body", self);
                ret = [[ChunkedInputStream alloc] initWithUnderlyingStream:self];
            } else {
                SETNSERROR(@"StreamErrorDomain", -1, @"unknown Transfer-Encoding '%@'", transferEncoding);
                return nil;
            }
            //        } else if (contentLength != nil) {
            //            int length = [contentLength intValue];
            //            BufferedInputStream *bis = [[BufferedInputStream alloc] initWithUnderlyingStream:self];
            //            HSLogTrace(@"%@: fixed-length response body (%d bytes)", self, length);
            ////            ret = [[FixedLengthInputStream alloc] initWithUnderlyingStream:bis length:(NSUInteger)length];
            ////            [bis release];
            //            ret = bis;
        } else {
            /* 
             * FIXME: handle multipart/byteranges media type.
             * See rfc2616 section 4.4 ("message length").
             */
            HSLogTrace(@"%@: response body with no content-length", self);
            ret = [self retain];
        }
    }
    return ret;
}
- (NSInteger)doRead:(unsigned char *)buf bufferLength:(NSUInteger)length error:(NSError **)error {
    NSInteger recvd = 0;
    for (;;) {
        NSTimeInterval timeoutSeconds = [httpTimeoutSetting timeoutSeconds];
        if (timeoutSeconds == 0) {
            timeoutSeconds = DEFAULT_TIMEOUT_SECONDS;
        }
        NSDate *timeout = [[NSDate date] addTimeInterval:timeoutSeconds];
        while (!complete && !hasBytesAvailable) {
            if ([timeout earlierDate:[NSDate date]] == timeout) {
                HSLogWarn(@"timed out after %0.2f seconds waiting for response data from %@ %@", timeoutSeconds, requestMethod, url);
                SETNSERROR([self errorDomain], ERROR_TIMEOUT, @"timeout after %0.2f seconds", timeoutSeconds);
                closeRequested = YES;
                return -1;
            }
            HSLogTrace(@"read: running the runloop until %@", timeout);
            [[NSRunLoop currentRunLoop] runMode:runLoopMode beforeDate:timeout];
        }
        hasBytesAvailable = NO;
        if (errorOccurred) {
            if (error != NULL) {
                *error = _error;
            }
            return -1;
        }
        if (complete) {
            return 0;
        }
        recvd = [readStream read:buf maxLength:length];
        HSLogTrace(@"received %d bytes", recvd);
        if (recvd < 0) {
            [self handleStreamError];
            if (error != NULL) {
                *error = _error;
            }
            return -1;
        }
        if (recvd > 0) {
            break;
        }
    }
    return recvd;    
}
@end

@implementation CFHTTPConnection (callback)
- (void)sentRequestBytes:(NSInteger)count {
    totalSent += count;
}
@end
