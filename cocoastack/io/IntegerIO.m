/*
 Copyright (c) 2009-2014, Stefan Reitshamer http://www.haystacksoftware.com
 
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

#import "IntegerIO.h"
#import "Streams.h"
#import "BufferedInputStream.h"
#import "BufferedOutputStream.h"

@implementation IntegerIO
//
// Big-endian network byte order.
//
+ (void)writeInt32:(int32_t)i to:(NSMutableData *)data {
    [IntegerIO writeUInt32:(uint32_t)i to:data];
}
+ (void)writeUInt32:(uint32_t)value to:(NSMutableData *)data {
    uint32_t nboValue = OSSwapHostToBigInt32(value);
    [data appendBytes:&nboValue length:4];
}
+ (BOOL)writeInt32:(int32_t)value to:(BufferedOutputStream *)os error:(NSError **)error {
    return [IntegerIO writeUInt32:(uint32_t)value to:os error:error];
}
+ (BOOL)writeUInt32:(uint32_t)value to:(BufferedOutputStream *)os error:(NSError **)error {
    uint32_t nboValue = OSSwapHostToBigInt32(value);
    return [os writeFully:(const unsigned char *)&nboValue length:4 error:error];
}
+ (void)writeInt64:(int64_t)value to:(NSMutableData *)data {
    [IntegerIO writeUInt64:(uint64_t)value to:data];
}
+ (void)writeUInt64:(uint64_t)value to:(NSMutableData *)data {
    uint64_t nboValue = OSSwapHostToBigInt64(value);
    [data appendBytes:&nboValue length:8];
}
+ (BOOL)writeInt64:(int64_t)value to:(BufferedOutputStream *)os error:(NSError **)error {
    return [IntegerIO writeUInt64:(uint64_t)value to:os error:error];
}
+ (BOOL)writeUInt64:(uint64_t)value to:(BufferedOutputStream *)os error:(NSError **)error {
    uint64_t nboValue = OSSwapHostToBigInt64(value);
    return [os writeFully:(const unsigned char *)&nboValue length:8 error:error];
}
+ (BOOL)readInt32:(int32_t *)value from:(BufferedInputStream *)is error:(NSError **)error {
    return [IntegerIO readUInt32:(uint32_t *)value from:is error:error];
}
+ (BOOL)readUInt32:(uint32_t *)value from:(BufferedInputStream *)is error:(NSError **)error {
    *value = 0;
    uint32_t nboValue = 0;
    if (![is readExactly:sizeof(uint32_t) into:(unsigned char *)&nboValue error:error]) {
        return NO;
    }
    *value = OSSwapBigToHostInt32(nboValue);
    return YES;
}
+ (BOOL)readInt64:(int64_t *)value from:(BufferedInputStream *)is error:(NSError **)error {
    return [IntegerIO readUInt64:(uint64_t *)value from:is error:error];
}
+ (BOOL)readUInt64:(uint64_t *)value from:(BufferedInputStream *)is error:(NSError **)error {
    *value = 0;
    uint64_t nboValue = 0;
    if (![is readExactly:sizeof(uint64_t) into:(unsigned char *)&nboValue error:error]) {
        return NO;
    }
    *value = OSSwapBigToHostInt64(nboValue);
    return YES;
}
@end
