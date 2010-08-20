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

#import "HTTPResponse.h"
#import "RegexKitLite.h"
#import "SetNSError.h"
#import "BufferedInputStream.h"
#import "DataInputStream.h"
#import "ChunkedInputStream.h"
#import "FixedLengthInputStream.h"
#import "InputStream.h"
#import "InputStreams.h"
#import "NSData-InputStream.h"
#import "FDInputStream.h"

#define MAX_HTTP_STATUS_LINE_LENGTH (8192)
#define MAX_HTTP_HEADER_LINE_LENGTH (8192)

@implementation HTTPResponse
- (id)init {
    if (self = [super init]) {
        headers = [[NSMutableDictionary alloc] init];
    }
    return self;
}
- (void)dealloc {
    [requestMethod release];
    [protocol release];
    [headers release];
    [super dealloc];
}
- (int)code {
    return code;
}
- (NSString *)protocol {
    return protocol;
}
- (NSString *)headerForKey:(NSString *)key {
    return [headers objectForKey:key];
}
- (unsigned long long)contentLength {
    long long contentLength = 0;
    NSString *str = [self headerForKey:@"Content-Length"];
    if (str != nil) {
        NSScanner *scanner = [NSScanner scannerWithString:str];
        if (![scanner scanLongLong:&contentLength]) {
            HSLogWarn(@"unable to scan Content-Length %@", str);
        }
    }
    return (unsigned long long)contentLength;
}
- (id <BufferedInputStream>)newResponseInputStream:(id <BufferedInputStream>)underlyingStream error:(NSError **)error {
    id <BufferedInputStream> ret = nil;
    if ([requestMethod isEqualToString:@"HEAD"] || code == 204) {
        ret = [[NSData data] newInputStream];
    } else {
        NSString *transferEncoding = [self headerForKey:@"Transfer-Encoding"];
        NSString *contentLength = [self headerForKey:@"Content-Length"];
        if (transferEncoding != nil) {
            if ([[transferEncoding lowercaseString] isEqualToString:@"chunked"]) {
                ret = [[ChunkedInputStream alloc] initWithUnderlyingStream:underlyingStream];
            } else {
                SETNSERROR(@"StreamErrorDomain", -1, @"unknown Transfer-Encoding: %@", transferEncoding);
            }
        } else if (contentLength != nil) {
            int length = [contentLength intValue];
            ret = [[FixedLengthInputStream alloc] initWithUnderlyingStream:underlyingStream length:(NSUInteger)length];
        } else {
            /* 
             * FIXME: handle multipart/byteranges media type.
             * See rfc2616 section 4.4 ("message length").
             */
            HSLogWarn(@"response body with no content-length");
            ret = [underlyingStream retain];
        }
    }
    return ret;
}
- (BOOL)readHead:(id <BufferedInputStream>)inputStream requestMethod:(NSString *)theRequestMethod error:(NSError **)error {
    [headers removeAllObjects];
    [requestMethod release];
    requestMethod = [theRequestMethod copy];
    NSString *line = [InputStreams readLineWithCRLF:inputStream maxLength:MAX_HTTP_STATUS_LINE_LENGTH error:error];
    if (line == nil) {
        return NO;
    }
    NSString *pattern = @"^HTTP/(1.\\d)\\s+(\\d+)\\s+(.+)\r\n$";
    NSRange protoRange = [line rangeOfRegex:pattern capture:1];
    NSRange codeRange = [line rangeOfRegex:pattern capture:2];
    if (protoRange.location == NSNotFound || codeRange.location == NSNotFound) {
        SETNSERROR(@"HTTPResponseErrorDomain", -1, @"unexpected response status line: %@", line);
        return NO;
    }
    protocol = [[line substringWithRange:protoRange] retain];
    code = [[line substringWithRange:codeRange] intValue];
    
    NSString *headerPattern = @"^([^:]+):\\s+(.+)\r\n$";
    for(;;) {
        line = [InputStreams readLineWithCRLF:inputStream maxLength:MAX_HTTP_HEADER_LINE_LENGTH error:error];
        if (line == nil) {
            return NO;
        }
        if ([line isEqualToString:@"\r\n"]) {
            break;
        }
        NSRange nameRange = [line rangeOfRegex:headerPattern capture:1];
        NSRange valueRange = [line rangeOfRegex:headerPattern capture:2];
        if (nameRange.location == NSNotFound || valueRange.location == NSNotFound) {
            SETNSERROR(@"HTTPResponseErrorDomain", -1, @"invalid response header: %@", line);
            return NO;
        }
        NSString *name = [line substringWithRange:nameRange];
        NSString *value = [line substringWithRange:valueRange];
        if ([headers objectForKey:name] != nil) {
            HSLogWarn(@"dumping response header %@ = %@", name, [headers objectForKey:name]);
        }
        [headers setObject:value forKey:name];
    }
    return YES;
}

#pragma mark NSObject protocol
- (NSString *)description {
    return [NSString stringWithFormat:@"<HTTPResponse %p: code=%d headers=%@>", self, code, headers];
}
@end
