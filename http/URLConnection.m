//
//  URLConnection.m
//  Arq
//
//  Created by Stefan Reitshamer on 5/3/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "URLConnection.h"
#import "RFC2616DateFormatter.h"
#import "InputStream.h"
#import "RegexKitLite.h"
#import "NSData-InputStream.h"
#import "ChunkedInputStream.h"
#import "SetNSError.h"
#import "DataInputStream.h"
#import "BufferedInputStream.h"
#import "InputStreams.h"
#import "NSErrorCodes.h"
#import "NSError_extra.h"
#import "Streams.h"


static NSString *RUN_LOOP_MODE = @"HTTPConnectionRunLoopMode";

@interface NSURLRequest (privateInterface)
+ (void)setAllowsAnyHTTPSCertificate:(BOOL)allow forHost:(NSString *)host;
@end

@interface URLConnection (internal)
- (void)subtractBytes;
@end

@implementation URLConnection
+ (NSString *)errorDomain {
    return @"URLConnectionErrorDomain";
}

- (id)initWithURL:(NSURL *)theURL method:(NSString *)theMethod delegate:(id)theDelegate {
    if (self = [super init]) {
        // Don't retain the delegate.
        delegate = theDelegate;
        method = [theMethod retain];
        mutableURLRequest = [[NSMutableURLRequest alloc] initWithURL:theURL];
        [mutableURLRequest setHTTPMethod:theMethod];
        [NSURLRequest setAllowsAnyHTTPSCertificate:YES forHost:[theURL host]];
        dateFormatter = [[RFC2616DateFormatter alloc] init];
        HSLogTrace(@"%@ %@", theMethod, theURL);
    }
    return self;
}
- (void)dealloc {
    [method release];
    [urlConnection unscheduleFromRunLoop:[NSRunLoop currentRunLoop] forMode:RUN_LOOP_MODE];
    [mutableURLRequest release];
    [urlConnection release];
    [httpURLResponse release];
    [dateFormatter release];
    [super dealloc];
}
- (void)setRequestHeader:(NSString *)value forKey:(NSString *)key {
    HSLogTrace(@"request header %@ = %@", key, value);
    [mutableURLRequest setValue:value forHTTPHeaderField:key];
}
- (void)setRequestHostHeader {
    [self setRequestHeader:[[mutableURLRequest URL] host] forKey:@"Host"];
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
    return [mutableURLRequest HTTPMethod];
}
- (NSString *)requestPathInfo {
    return [[[mutableURLRequest URL] path] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
}
- (NSString *)requestQueryString {
    return [[mutableURLRequest URL] query];
}
- (NSArray *)requestHeaderKeys {
    return [[mutableURLRequest allHTTPHeaderFields] allKeys];
}
- (NSString *)requestHeaderForKey:(NSString *)theKey {
    return [[mutableURLRequest allHTTPHeaderFields] objectForKey:theKey];
}
- (BOOL)executeRequest:(NSError **)error {
    return [self executeRequestWithBody:nil error:error];
}
- (BOOL)executeRequestWithBody:(NSData *)theBody error:(NSError **)error {
    if (theBody != nil) {
        [mutableURLRequest setHTTPBody:theBody];
    }
    totalSent = 0;
    NSAssert(urlConnection == nil, @"can't call this method more than once!");
    urlConnection = [[NSURLConnection alloc] initWithRequest:mutableURLRequest delegate:self startImmediately:NO];
    [urlConnection scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:RUN_LOOP_MODE];
    [urlConnection start];
    return YES;
}
- (int)responseCode {
    return [httpURLResponse statusCode];
}
- (NSString *)responseHeaderForKey:(NSString *)key {
    return [[httpURLResponse allHeaderFields] objectForKey:key];
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
    while (!complete && offset >= [receivedData length]) {
        [[NSRunLoop currentRunLoop] runMode:RUN_LOOP_MODE beforeDate:[NSDate distantFuture]];
    }
    if (_error) {
        if (error != NULL) {
            *error = _error;
        }
        [self subtractBytes];
        return nil;
    }
    
    id <InputStream> ret = nil;
    if ([method isEqualToString:@"HEAD"] && complete) {
        HSLogTrace(@"%@: empty response body", self);
        ret = [[NSData data] newInputStream];
    } else {
        NSAssert(httpURLResponse != nil, @"httpURLResponse can't be nil");
        NSString *transferEncoding = [self responseHeaderForKey:@"Transfer-Encoding"];
        HSLogTrace(@"Content-Length = %@", [self responseHeaderForKey:@"Content-Length"]);
        HSLogTrace(@"Transfer-Encoding = %@", transferEncoding);
        if (transferEncoding != nil && ![transferEncoding isEqualToString:@"Identity"]) {
            if ([[transferEncoding lowercaseString] isEqualToString:@"chunked"]) {
                HSLogTrace(@"%@: chunked response body", self);
                id <InputStream> underlying = self;
                BufferedInputStream *bis = [[BufferedInputStream alloc] initWithUnderlyingStream:underlying];
                ret = [[ChunkedInputStream alloc] initWithUnderlyingStream:bis];
                [bis release];
            } else {
                SETNSERROR(@"StreamErrorDomain", -1, @"unknown Transfer-Encoding '%@'", transferEncoding);
                [self subtractBytes];
                return nil;
            }
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

#pragma mark InputStream
- (NSInteger)read:(unsigned char *)buf bufferLength:(NSUInteger)length error:(NSError **)error {
    NSInteger recvd = 0;
    while (!complete && offset >= [receivedData length]) {
        [[NSRunLoop currentRunLoop] runMode:RUN_LOOP_MODE beforeDate:[NSDate distantFuture]];
    }
    if (_error) {
        if (error != NULL) {
            *error = _error;
        }
        [self subtractBytes];
        return -1;
    }
    
    NSUInteger bytesRemaining = [receivedData length] - offset;
    recvd = (length < bytesRemaining) ? length : bytesRemaining;
    totalReceived += recvd;
    memcpy(buf, (unsigned char *)[receivedData bytes] + offset, recvd);
    offset += recvd;
    if (offset == [receivedData length]) {
        [receivedData release];
        receivedData = nil;
        offset = 0;
    }
    HSLogTrace(@"received %ld bytes", recvd);

    return recvd;    
}
- (NSData *)slurp:(NSError **)error {
    NSMutableData *ret = [NSMutableData data];
    
    if (receivedData != nil) {
        [ret appendData:receivedData];
        [receivedData release];
        receivedData = nil;
        offset = 0;
    }
    for (;;) {
        while (!complete && offset >= [receivedData length]) {
            [[NSRunLoop currentRunLoop] runMode:RUN_LOOP_MODE beforeDate:[NSDate distantFuture]];
        }
        if (_error) {
            if (error != NULL) { *error = _error; }
            return nil;
        }
        if (receivedData != nil) {
            [ret appendData:receivedData];
            [receivedData release];
            receivedData = nil;
        }
        if (complete) {
            break;
        }
    }
    return ret;
}

#pragma mark NSURLConnection delegate
- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)myError {
    HSLogDebug(@"%@ %@: %@", method, [mutableURLRequest URL], myError);
    [_error release];
    _error = [myError retain];
    complete = YES;
}
- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    NSAssert(receivedData == nil, @"must not discard unread bytes");
    HSLogTrace(@"received %lu bytes", [data length]);
    [receivedData release];
    receivedData = [data retain];
    offset = 0;
}
- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
        [httpURLResponse release];
        httpURLResponse = (NSHTTPURLResponse *)[response retain];
    }
}
- (void)connection:(NSURLConnection *)connection didSendBodyData:(NSInteger)bytesWritten totalBytesWritten:(NSInteger)totalBytesWritten totalBytesExpectedToWrite:(NSInteger)totalBytesExpectedToWrite {
    HSLogTrace(@"%@: sent so far %lu of %lu", self, totalBytesWritten, totalBytesExpectedToWrite);
}
- (NSCachedURLResponse *)connection:(NSURLConnection *)connection willCacheResponse:(NSCachedURLResponse *)cachedResponse {
    return cachedResponse;
}
- (NSURLRequest *)connection:(NSURLConnection *)connection willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)redirectResponse {
    return request;
}
- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    complete = YES;
}

#pragma mark NSObject
- (NSString *)description {
    return [NSString stringWithFormat:@"<URLConnection: %@>", [mutableURLRequest URL]];
}
@end

@implementation URLConnection (internal)
- (void)subtractBytes {
    if (totalSent > 0 && [delegate respondsToSelector:@selector(urlConnection:subtractSentBytes:)]) {
        [delegate urlConnection:self subtractSentBytes:totalSent];
        totalSent = 0;
    }
}
@end
