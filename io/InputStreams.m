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

#import "InputStreams.h"
#import "SetNSError.h"
#import "NSErrorCodes.h"
#import "BufferedInputStream.h"

#define MY_BUF_SIZE (8192)

@implementation InputStreams
+ (NSData *)slurp:(id <InputStream>)is error:(NSError **)error {
    NSMutableData *data = [[[NSMutableData alloc] init] autorelease];
    unsigned char *buf = (unsigned char *)malloc(MY_BUF_SIZE);
    NSInteger ret = 0;
    for (;;) {
        ret = [is read:buf bufferLength:MY_BUF_SIZE error:error];
        if (ret <= 0) {
            break;
        }
        [data appendBytes:buf length:ret];
    }
    free(buf);
    if (ret == -1) {
        return nil;
    }
    return data;
}
+ (NSString *)readLineWithCRLF:(BufferedInputStream *)bis maxLength:(NSUInteger)maxLength error:(NSError **)error {
    unsigned char *buf = (unsigned char *)malloc(maxLength);
    NSUInteger received = 0;
    for (;;) {
        if (received > maxLength) {
            SETNSERROR(@"InputStreamErrorDomain", -1, @"exceeded maxLength %u before finding CRLF", maxLength);
            return nil;
        }
        if (![bis readExactly:1 into:(buf + received) error:error]) {
            return nil;
        }
        received++;
        if (received >= 2 && buf[received - 1] == '\n' && buf[received - 2] == '\r') {
            break;
        }
    }
    NSString *ret = [[[NSString alloc] initWithBytes:buf length:received encoding:NSUTF8StringEncoding] autorelease];
    HSLogTrace(@"got line <%@>", ret);
    return ret;
}
+ (NSString *)readLine:(BufferedInputStream *)bis error:(NSError **)error {
    NSMutableData *data = [NSMutableData data];
    unsigned char buf[1];
    NSUInteger received = 0;
    for (;;) {
        if (![bis readExactly:1 into:buf error:error]) {
            return nil;
        }
        if (*buf == '\n') {
            break;
        }
        [data appendBytes:buf length:1];
        received++;
    }
    NSString *ret = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
    HSLogTrace(@"got line <%@> followed by \\n", ret);
    return ret;
}
@end
