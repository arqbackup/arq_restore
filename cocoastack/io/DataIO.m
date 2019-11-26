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



#import "DataIO.h"
#import "IntegerIO.h"
#import "BufferedInputStream.h"
#import "BufferedOutputStream.h"

@implementation DataIO
+ (void)write:(NSData *)data to:(NSMutableData *)outData {
    [IntegerIO writeUInt64:(uint64_t)[data length] to:outData];
    [outData appendBytes:[data bytes] length:[data length]];
}
+ (BOOL)write:(NSData *)data to:(BufferedOutputStream *)os error:(NSError **)error {
    return ([IntegerIO writeUInt64:[data length] to:os error:error] && [os writeFully:[data bytes] length:[data length] error:error]);
}

+ (BOOL)read:(NSData **)value from:(BufferedInputStream *)is error:(NSError **)error {
    *value = nil;
    uint64_t length = 0;
    if (![IntegerIO readUInt64:&length from:is error:error]) {
        return NO;
    }
    *value = [is readExactly:(NSUInteger)length error:error];
    return *value != nil;
}

@end
