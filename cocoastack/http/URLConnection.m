/*
 Copyright (c) 2009-2017, Haystack Software LLC https://www.arqbackup.com
 
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



#import "URLConnection.h"
#import "RFC2616DateFormatter.h"
#import "InputStream.h"
#import "NSData-InputStream.h"
#import "ChunkedInputStream.h"
#import "SetNSError.h"
#import "DataInputStream.h"
#import "BufferedInputStream.h"
#import "InputStreams.h"
#import "NSErrorCodes.h"
#import "NSError_extra.h"
#import "Streams.h"
#import "DataTransferDelegate.h"
#import "RegexKitLite.h"
#import "System.h"
#import "HTTPInputStream.h"


static NSString *RUN_LOOP_MODE = @"HTTPConnectionRunLoopMode";
#define DEFAULT_TIMEOUT_SECONDS (90)


@implementation URLConnection

- (id)initWithURL:(NSURL *)theURL method:(NSString *)theMethod dataTransferDelegate:(id<DataTransferDelegate>)theDelegate {
    if (self = [super init]) {
        // Don't retain the delegate.
        delegate = theDelegate;
        method = [theMethod retain];
        url = [theURL retain];
        mutableURLRequest = [[NSMutableURLRequest alloc] initWithURL:theURL];
        [mutableURLRequest setHTTPMethod:theMethod];
        [mutableURLRequest setCachePolicy:NSURLRequestReloadIgnoringCacheData];
        
        NSAssert(theURL != nil, @"theURL may not be nil");
        
        HSLogDebug(@"%@ %@", theMethod, theURL);
        responseData = [[NSMutableData alloc] init];
        createTime = [NSDate timeIntervalSinceReferenceDate];
    }
    return self;
}
- (void)dealloc {
    [method release];
    [url release];
    [urlConnection unscheduleFromRunLoop:[NSRunLoop currentRunLoop] forMode:RUN_LOOP_MODE];
    [mutableURLRequest release];
    [urlConnection release];
    [httpURLResponse release];
    [responseData release];
    [_error release];
    [date release];
    [super dealloc];
}


#pragma mark HTTPConnection
- (NSString *)errorDomain {
    return @"HTTPConnectionErrorDomain";
}
- (NSURL *)URL {
    return url;
}

- (void)setRequestHeader:(NSString *)value forKey:(NSString *)key {
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
    [self setRFC822DateRequestHeader:[NSDate date]];
}
- (void)setRFC822DateRequestHeader:(NSDate *)theDate {
    [self setRequestHeader:[[RFC2616DateFormatter sharedRFC2616DateFormatter] rfc2616StringFromDate:theDate] forKey:@"Date"];
}
- (void)setDate:(NSDate *)theDate {
    [theDate retain];
    [date release];
    date = theDate;
}
- (NSDate *)date {
    return date;
}
- (NSString *)requestMethod {
    return [mutableURLRequest HTTPMethod];
}
- (NSString *)requestPathInfo {
    NSString *urlDescription = [[mutableURLRequest URL] description];
    NSRange rangeBeforeQueryString = [urlDescription rangeOfRegex:@"^([^?]+)"];
    NSString *stringBeforeQueryString = [urlDescription substringWithRange:rangeBeforeQueryString];
    NSString *path = [[mutableURLRequest URL] path];
    if ([stringBeforeQueryString hasSuffix:@"/"] && ![path hasSuffix:@"/"]) {
        // NSURL's path method strips trailing slashes. Add it back in.
        path = [path stringByAppendingString:@"/"];
    }
    return [path stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
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
- (NSData *)executeRequest:(NSError **)error {
    return [self executeRequestWithBody:nil error:error];
}
- (NSData *)executeRequestWithBody:(NSData *)theBody error:(NSError **)error {
    if ([theBody length] > 0) {
        httpInputStream = [[HTTPInputStream alloc] initWithHTTPConnection:self data:theBody]; // Don't retain this?!
        [mutableURLRequest setHTTPBodyStream:(NSInputStream *)httpInputStream];
        [httpInputStream release];
    } else if (theBody != nil) {
        // For 0-byte body, HTTPInputStream seems to hang, so just give it an empty NSData:
        [mutableURLRequest setHTTPBody:theBody];
    }
    
    [responseData setLength:0];
    urlConnection = [[NSURLConnection alloc] initWithRequest:mutableURLRequest delegate:self startImmediately:NO];
    [urlConnection scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:RUN_LOOP_MODE];
    [urlConnection start];

    if (theBody != nil) {
        HSLogDebug(@"NSURLConnection started with request body (%ld bytes)", (unsigned long)[theBody length]);
    } else {
        HSLogDebug(@"NSURLConnection started with no request body");
    }
    
    [[NSUserDefaults standardUserDefaults] synchronize];
    NSTimeInterval timeoutInterval = (NSTimeInterval)[[NSUserDefaults standardUserDefaults] doubleForKey:@"HTTPTimeoutSeconds"];
    if (timeoutInterval == 0) {
        timeoutInterval = DEFAULT_TIMEOUT_SECONDS;
    }
    [mutableURLRequest setTimeoutInterval:timeoutInterval];
    
//    HSLogDebug(@"HTTPTimeoutSeconds=%0.3f", timeoutInterval);

    // Loop to read in the whole damn response body because the streaming approach doesn't work reliably with Apple's stupid URL loading system.
    while (urlConnection != nil) {
        NSTimeInterval runToInterval = [NSDate timeIntervalSinceReferenceDate] + timeoutInterval;

        [[NSRunLoop currentRunLoop] runMode:RUN_LOOP_MODE beforeDate:[NSDate dateWithTimeIntervalSinceReferenceDate:runToInterval]];
        
        if (urlConnection != nil) {
            NSTimeInterval current = [NSDate timeIntervalSinceReferenceDate];
            // HSLogDebug(@"elapsed: %0.3f seconds", (current - runToInterval + timeoutInterval)); //FIXME: remove this
            if ((current - runToInterval) > 0) {
                HSLogWarn(@"exceeded timeout of %0.3f seconds during %@ %@", timeoutInterval, method, [mutableURLRequest URL]);
                _error = [[NSError alloc] initWithDomain:[self errorDomain] code:ERROR_TIMEOUT description:[NSString stringWithFormat:@"timeout during %@ %@", method, [mutableURLRequest URL]]];
                errorOccurred = YES;
                [urlConnection cancel];
                [urlConnection release];
                urlConnection = nil;
            }
        }
    }
    if (errorOccurred) {
        [delegate dataTransferDidFail];
        if (error != NULL) {
            *error = [[_error retain] autorelease];
        }
        return nil;
    }
    
    NSData *ret = nil;
    if ([method isEqualToString:@"HEAD"]) {
        ret = [NSData data];
    } else {
        NSAssert(httpURLResponse != nil, @"httpURLResponse can't be nil");
        NSString *contentLength = [self responseHeaderForKey:@"Content-Length"];
        NSString *transferEncoding = [self responseHeaderForKey:@"Transfer-Encoding"];
        HSLogDebug(@"response: status = %d, Content-Length = %@, Transfer-Encoding = %@", [self responseCode], contentLength, transferEncoding);
        if (transferEncoding != nil && ![transferEncoding isEqualToString:@"Identity"]) {
            if ([[transferEncoding lowercaseString] isEqualToString:@"chunked"]) {
                id <InputStream> dis = [[[DataInputStream alloc] initWithData:responseData description:@"http response"] autorelease];
                BufferedInputStream *bis = [[[BufferedInputStream alloc] initWithUnderlyingStream:dis] autorelease];
                ChunkedInputStream *cis = [[[ChunkedInputStream alloc] initWithUnderlyingStream:bis] autorelease];
                ret = [cis slurp:error];
            } else {
                SETNSERROR(@"StreamErrorDomain", -1, @"unknown Transfer-Encoding '%@'", transferEncoding);
                return nil;
            }
        } else {
            /*
             * FIXME: handle multipart/byteranges media type.
             * See rfc2616 section 4.4 ("message length").
             */
            HSLogDebug(@"response body with no Transfer-Encoding; responseData is %ld bytes", (unsigned long)[responseData length]);
            ret = responseData;
        }
        
//        // If the response had "Content-Encoding: gzip" header, then NSURLConnection gunzipped it for us already and the responseData length won't match the Content-Length!
//        if (contentLength != nil && [contentLength integerValue] != [responseData length] && ![[self responseHeaderForKey:@"Content-Encoding"] isEqualToString:@"gzip"] && ![[self responseHeaderForKey:@"Content-Encoding"] isEqualToString:@"deflate"]) {
//            NSString *errorMessage = [NSString stringWithFormat:@"Actual response length %ld does not match Content-Length %@ for %@", (unsigned long)[responseData length], contentLength, [mutableURLRequest URL]];
//            HSLogError(@"%@", errorMessage);
//            if ([[HSLog sharedHSLog] hsLogLevel] >= HSLOG_LEVEL_DEBUG) {
//                NSDictionary *headers = [self responseHeaders];
//                for (NSString *key in [headers allKeys]) {
//                    HSLogDebug(@"response header: %@ = %@", key, [headers objectForKey:key]);
//                }
//                NSString *responseString = [[[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding] autorelease];
//                HSLogDebug(@"response string: %@", responseString);
//            }
//            SETNSERROR([self errorDomain], -1, @"%@", errorMessage);
//            return nil;
//        }
    }
    NSAssert(ret != nil, @"ret may not be nil");
    return ret;
}
- (int)responseCode {
    return (int)[httpURLResponse statusCode];
}
- (NSDictionary *)responseHeaders {
    return [httpURLResponse allHeaderFields];
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

- (BOOL)errorOccurred {
    return errorOccurred;
}
- (NSTimeInterval)createTime {
    return createTime;
}


#pragma mark NSURLConnection delegate
- (BOOL)connection:(NSURLConnection *)connection canAuthenticateAgainstProtectionSpace:(NSURLProtectionSpace *)protectionSpace {
    return [protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust];
}

- (void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
//    if ([delegate httpConnectionAcceptsAnyHTTPSCertificate]) {
//        [challenge.sender useCredential:[NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust] forAuthenticationChallenge:challenge];
//    } else {
        [challenge.sender continueWithoutCredentialForAuthenticationChallenge:challenge];
//    }
}
- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
        [httpURLResponse release];
        httpURLResponse = (NSHTTPURLResponse *)[response retain];
        // Docs state "Each time the delegate receives the connection:didReceiveResponse: message, it should reset any progress indication and discard all previously received data.".
//        HSLogDebug(@"didReceiveResponse; resetting responseData");
        [responseData setLength:0];
    }
}
- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)myError {
    HSLogDebug(@"connection didFailWithError: %@", myError);
    errorOccurred = YES;
    [_error release];
    _error = [myError retain];
    [urlConnection release];
    urlConnection = nil;
}
- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    if ([data length] > 0) {
        [responseData appendData:data];
        if ([delegate respondsToSelector:@selector(dataTransferDidDownloadBytes:httpThrottle:error:)]) {
            NSUInteger bytesReceivedThisTime = [data length];
            HTTPThrottle *httpThrottle = nil;
            if (![delegate dataTransferDidDownloadBytes:bytesReceivedThisTime httpThrottle:&httpThrottle error:&_error]) {
                [_error retain];
                errorOccurred = YES;
                [urlConnection cancel];
                [urlConnection release];
                urlConnection = nil;
            }
            if (httpThrottle != nil) {
                [httpInputStream setHTTPThrottle:httpThrottle];
            }
        }
    }
}
- (void)connection:(NSURLConnection *)connection didSendBodyData:(NSInteger)bytesWritten totalBytesWritten:(NSInteger)theTotalBytesWritten totalBytesExpectedToWrite:(NSInteger)totalBytesExpectedToWrite {
//    HSLogDebug(@"did send %ld bytes", bytesWritten);
    if ([delegate respondsToSelector:@selector(dataTransferDidUploadBytes:httpThrottle:error:)]) {
        NSUInteger bytesSentThisTime = bytesWritten;
        HTTPThrottle *httpThrottle = nil;
        if (![delegate dataTransferDidUploadBytes:bytesSentThisTime httpThrottle:&httpThrottle error:&_error]) {
            [_error retain];
            errorOccurred = YES;
            [urlConnection cancel];
            [urlConnection release];
            urlConnection = nil;
        }
        if (httpThrottle != nil) {
            [httpInputStream setHTTPThrottle:httpThrottle];
        }
    }
    totalBytesSent = theTotalBytesWritten;
}
- (NSCachedURLResponse *)connection:(NSURLConnection *)connection willCacheResponse:(NSCachedURLResponse *)cachedResponse {
    return nil;
}
- (NSURLRequest *)connection:(NSURLConnection *)connection willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)redirectResponse {
    return request;
}
- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
//    HSLogDebug(@"connectionDidFinishLoading");
    [urlConnection release];
    urlConnection = nil;
}


#pragma mark NSObject
- (NSString *)description {
    return [NSString stringWithFormat:@"<URLConnection: %@ %@>", method, [mutableURLRequest URL]];
}
@end
