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
@protocol HTTPConnectionDelegate;
#import "InputStream.h"
@class RFC2616DateFormatter;
@class HTTPTimeoutSetting;

@interface CFHTTPConnection : NSObject <HTTPConnection, InputStream> {
    RFC2616DateFormatter *dateFormatter;
    NSURL *url;
    NSString *requestMethod;
    id <HTTPConnectionDelegate> httpConnectionDelegate;
    NSMutableDictionary *requestHeaders;
    CFHTTPMessageRef request;
    NSInputStream *readStream;
    BOOL errorOccurred;
    NSError *_error;
    BOOL complete;
    BOOL hasBytesAvailable;
    int responseStatusCode;
    NSDictionary *responseHeaders;
    NSTimeInterval createTime;
    BOOL closeRequested;
    CFHTTPConnection *previous;
    NSDate *sendTimeout;
    unsigned long long totalSent;
    HTTPTimeoutSetting *httpTimeoutSetting;
}
+ (NSString *)errorDomain;
- (id)initWithURL:(NSURL *)theURL method:(NSString *)theMethod httpTimeoutSetting:(HTTPTimeoutSetting *)theHTTPTimeoutSetting httpConnectionDelegate:(id <HTTPConnectionDelegate>)theDelegate;
- (id)initWithURL:(NSURL *)theURL method:(NSString *)theMethod httpTimeoutSetting:(HTTPTimeoutSetting *)theHTTPTimeoutSetting httpConnectionDelegate:(id <HTTPConnectionDelegate>)theDelegate previousConnection:(CFHTTPConnection *)thePrevious;
- (void)setRequestHeader:(NSString *)value forKey:(NSString *)key;
- (void)setRequestHostHeader;
- (void)setRequestContentDispositionHeader:(NSString *)downloadName;
- (void)setRFC822DateRequestHeader;
- (NSString *)requestMethod;
- (NSString *)requestPathInfo;
- (NSString *)requestQueryString;
- (NSArray *)requestHeaderKeys;
- (NSString *)requestHeaderForKey:(NSString *)theKey;
- (BOOL)executeRequest:(NSError **)error;
- (BOOL)executeRequestWithBody:(NSData *)requestBody error:(NSError **)error;
- (int)responseCode;
- (NSString *)responseHeaderForKey:(NSString *)key;
- (NSString *)responseContentType;
- (NSString *)responseDownloadName;
- (id <InputStream>)newResponseBodyStream:(NSError **)error;
- (void)setCloseRequested;
- (BOOL)isCloseRequested;
- (NSTimeInterval)createTime;
- (void)releasePreviousConnection;
@end
