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




#import "InputStreams.h"


#import "BufferedInputStream.h"

#define MY_BUF_SIZE (4096)

@implementation InputStreams
+ (NSData *)slurp:(id <InputStream>)is error:(NSError **)error {
    NSMutableData *data = [[[NSMutableData alloc] init] autorelease];
    if (![InputStreams slurp:is intoBuffer:data error:error]) {
        return nil;
    }
    return data;
}
+ (BOOL)slurp:(id <InputStream>)is intoBuffer:(NSMutableData *)theBuffer error:(NSError **)error {
    [theBuffer setLength:0];
    
    unsigned char *buf = (unsigned char *)malloc(MY_BUF_SIZE);
    NSInteger ret = 0;
    for (;;) {
        ret = [is read:buf bufferLength:MY_BUF_SIZE error:error];
        if (ret <= 0) {
            break;
        }
        [theBuffer appendBytes:buf length:ret];
    }
    free(buf);
    if (ret == -1) {
        return NO;
    }
    return YES;
}

@end
