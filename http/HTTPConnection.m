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

#import "HTTPConnection.h"
#import "HTTPRequest.h"
#import "HTTPResponse.h"
#import "StreamPairFactory.h"
#import "StreamPair.h"
#import "Streams.h"
#import "RegexKitLite.h"
#import "FDOutputStream.h"
#import "FDInputStream.h"

@implementation HTTPConnection
- (id)initWithHost:(NSString *)theHost useSSL:(BOOL)isUseSSL error:(NSError **)error {
    if (self = [super init]) {
        streamPair = [[StreamPairFactory theFactory] newStreamPairToHost:theHost useSSL:isUseSSL error:error];
        if (streamPair == nil) {
            [self release];
            return nil;
        }
        request = [[HTTPRequest alloc] initWithHost:theHost];
        response = [[HTTPResponse alloc] init];
    }
    return self;
}
- (void)dealloc {
    [streamPair release];
    [request release];
    [response release];
    [super dealloc];
}
- (void)setRequestMethod:(NSString *)theRequestMethod pathInfo:(NSString *)thePathInfo queryString:(NSString *)theQueryString protocol:(NSString *)theProtocol {
    [request setMethod:theRequestMethod];
    [request setPathInfo:thePathInfo];
    [request setQueryString:theQueryString];
    [request setProtocol:theProtocol];
}
- (void)setRequestHeader:(NSString *)value forKey:(NSString *)key {
    [request setHeader:value forKey:key];
}
- (void)setRequestHostHeader {
    [request setHostHeader];
}
- (void)setRequestKeepAliveHeader {
    [request setKeepAliveHeader];
}
- (void)setRequestContentDispositionHeader:(NSString *)downloadName {
    [request setContentDispositionHeader:downloadName];
}
- (void)setRFC822DateRequestHeader {
    [request setRFC822DateHeader];
}
- (BOOL)executeRequest:(NSError **)error {
    return [self executeRequestWithBody:nil error:error];
}
- (BOOL)executeRequestWithBody:(id <InputStream>)bodyStream error:(NSError **)error {
    if (![request write:streamPair error:error]) {
        return NO;
    }
    if (bodyStream != nil && ![Streams transferFrom:bodyStream to:streamPair error:error]) {
        return NO;
    }
    if (![response readHead:streamPair requestMethod:[request method] error:error]) {
        return NO;
    }
    if ([[response headerForKey:@"Connection"] isEqualToString:@"Close"]) {
        HSLogDebug(@"Connection: Close header received; requesting close on %@", streamPair);
        [streamPair setCloseRequested];
    }
    if (![[response protocol] isEqualToString:@"1.1"]) {
        HSLogDebug(@"protocol %@ HTTP response; requesting close on %@", [response protocol], streamPair);
        [streamPair setCloseRequested];
    }
    return YES;
}
- (int)responseCode {
    return [response code];
}
- (NSString *)responseHeaderForKey:(NSString *)key {
    return [response headerForKey:key];
}
- (NSString *)responseMimeType {
    return [response headerForKey:@"Content-Type"];
}
- (NSString *)responseDownloadName {
    NSString *downloadName = nil;
    NSString *contentDisposition = [response headerForKey:@"Content-Disposition"];
    if (contentDisposition != nil) {
        NSRange filenameRange = [contentDisposition rangeOfRegex:@"attachment;filename=(.+)" capture:1];
        if (filenameRange.location != NSNotFound) {
            downloadName = [contentDisposition substringWithRange:filenameRange];
        }
    }
    return downloadName;
}
- (id <BufferedInputStream>)newResponseBodyStream:(NSError **)error {
    return [response newResponseInputStream:streamPair error:error];
}
- (NSData *)slurpResponseBody:(NSError **)error {
    id <InputStream> is = [self newResponseBodyStream:error];
    if (is == nil) {
        return nil;
    }
    NSData *data = [is slurp:error];
    [is release];
    return data;
}
- (void)setCloseRequested {
    [streamPair setCloseRequested];
}
@end
