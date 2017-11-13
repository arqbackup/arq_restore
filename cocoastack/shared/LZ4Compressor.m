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



#include "lz4.h"
#import "LZ4Compressor.h"

@implementation LZ4Compressor
CWL_SYNTHESIZE_SINGLETON_FOR_CLASS(LZ4Compressor)

- (id)init {
    if (self = [super init]) {
        lock = [[NSLock alloc] init];
        [lock setName:@"LZ4Compressor lock"];
    }
    return self;
}

- (NSString *)errorDomain {
    return @"LZ4ErrorDomain";
}
- (NSData *)lz4Deflate:(NSData *)data error:(NSError **)error {
    [lock lock];
    NSData *ret = [self lockedLZ4Deflate:data error:error];
    [lock unlock];
    return ret;
}
- (NSData *)lz4Inflate:(NSData *)data error:(NSError **)error {
    [lock lock];
    NSData *ret = [self lockedLZ4Inflate:data error:error];
    [lock unlock];
    return ret;
}



- (NSData *)lockedLZ4Deflate:(NSData *)data error:(NSError **)error {
    if ([data length] > (NSUInteger)INT_MAX) {
        SETNSERROR([self errorDomain], -1, @"length larger than INT_MAX");
        return nil;
    }
    
    int originalSize = (int)[data length];
    if (originalSize == 0) {
        return [NSData data];
    }
    
    int destSize = LZ4_compressBound((int)[data length]);
    int outBufSize = destSize + 4;
    char *outBuf = (char *)malloc(outBufSize);
    
    int compressed = LZ4_compress_default([data bytes], outBuf + 4, (int)[data length], destSize);
    if (compressed == 0) {
        SETNSERROR([self errorDomain], -1, @"LZ4_compress_default failed");
        free(outBuf);
        return nil;
    }
    uint32_t nboSize = OSSwapHostToBigInt32(originalSize);
    memcpy(outBuf, &nboSize, 4);
    return [NSData dataWithBytesNoCopy:outBuf length:(compressed + 4) freeWhenDone:YES];
}

- (NSData *)lockedLZ4Inflate:(NSData *)data error:(NSError **)error {
    int length = (int)[data length];
    if (length < 5) {
        SETNSERROR([self errorDomain], -1, @"not enough bytes for an lz4-compressed buffer");
        return nil;
    }
    char *src = (char *)[data bytes];
    uint32_t nboSize = 0;
    memcpy(&nboSize, src, 4);
    int originalSize = OSSwapBigToHostInt32(nboSize);
    if (originalSize < 0) {
        SETNSERROR([self errorDomain], -1, @"invalid size for LZ4-compressed %d-byte data chunk: %d", length, originalSize);
        return nil;
    }
    char *buf = (char *)malloc(originalSize);
    int compressedSize = length - 4;
    int decompressedLen = LZ4_decompress_safe(src + 4, buf, compressedSize, originalSize);
    if (decompressedLen != originalSize) {
        HSLogError(@"LZ4_decompress error: returned %d (expected %d)", decompressedLen, originalSize);
        SETNSERROR([self errorDomain], -1, @"LZ4_decompress failed");
        return nil;
    }
    return [[[NSData alloc] initWithBytesNoCopy:buf length:originalSize freeWhenDone:YES] autorelease];
}

@end
