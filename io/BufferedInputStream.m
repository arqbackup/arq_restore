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

#import "BufferedInputStream.h"
#import "InputStream.h"
#import "NSErrorCodes.h"
#import "InputStreams.h"
#import "SetNSError.h"

#define MY_BUF_SIZE (8192)

@implementation BufferedInputStream
+ (NSString *)errorDomain {
    return @"BufInputStreamErrorDomain";
}
- (id)initWithUnderlyingStream:(id <InputStream>)theUnderlyingStream {
    if (self = [super init]) {
        underlyingStream = [theUnderlyingStream retain];
        buf = (unsigned char *)malloc(MY_BUF_SIZE);
        pos = 0;
        len = 0;
    }
    return self;
}
- (void)dealloc {
    [underlyingStream release];
    free(buf);
    [super dealloc];
}
- (NSData *)readExactly:(NSUInteger)exactLength error:(NSError **)error {
    NSMutableData *data = [NSMutableData dataWithLength:exactLength];
    unsigned char *dataBuf = [data mutableBytes];
    if (![self readExactly:exactLength into:dataBuf error:error]) {
        return nil;
    }
    return data;
}
- (BOOL)readExactly:(NSUInteger)exactLength into:(unsigned char *)outBuf error:(NSError **)error {
    if (exactLength > 2147483648) {
        SETNSERROR(@"InputStreamErrorDomain", -1, @"absurd length %u requested", exactLength);
        return NO;
    }
    NSUInteger received = 0;
    while (received < exactLength) {
        NSInteger ret = [self read:(outBuf + received) bufferLength:(exactLength - received) error:error];
        if (ret == -1) {
            return NO;
        }
        if (ret == 0) {
            SETNSERROR([BufferedInputStream errorDomain], ERROR_EOF, @"EOF after %u of %u bytes received", received, exactLength);
            return NO;
        }
        received += ret;
        totalBytesReceived += ret;
    }
    return YES;
}
- (uint64_t)bytesReceived {
    return totalBytesReceived;
}

#pragma mark InputStream
- (NSInteger)read:(unsigned char *)outBuf bufferLength:(NSUInteger)outBufLen error:(NSError **)error {
    NSInteger ret = 0;
    NSUInteger remaining = len - pos;
    if (remaining > 0) {
        // Return bytes from my buf:
        ret = remaining > outBufLen ? outBufLen : remaining;
        memcpy(outBuf, buf + pos, ret);
        pos += ret;
    } else if (outBufLen > MY_BUF_SIZE) {
        // Read direct into outBuf:
        ret = [underlyingStream read:outBuf bufferLength:outBufLen error:error];
    } else {
        // Read into my buf and return only what's asked for.
        NSInteger myRet = [underlyingStream read:buf bufferLength:MY_BUF_SIZE error:error];
        if (myRet < 0) {
            return myRet;
        }
        pos = 0;
        len = myRet;
        if (len > 0) {
            ret = len > outBufLen ? outBufLen : len;
            memcpy(outBuf, buf + pos, ret);
            pos += ret;
       } else {
           ret = 0;
       }
    }
    return ret;
}
- (NSData *)slurp:(NSError **)error {
    return [InputStreams slurp:self error:error];
}
@end
