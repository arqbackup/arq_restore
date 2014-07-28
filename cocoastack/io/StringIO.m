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
#import "StringIO.h"
#import "DataInputStream.h"
#import "Streams.h"
#import "NSData-InputStream.h"
#import "BooleanIO.h"
#import "BufferedInputStream.h"
#import "BufferedOutputStream.h"


@implementation StringIO
+ (void)write:(NSString *)str to:(NSMutableData *)data {
    [BooleanIO write:(str != nil) to:data];
    if (str != nil) {
        const char *utf8 = [str UTF8String];
        uint64_t len = (uint64_t)strlen(utf8);
        [IntegerIO writeUInt64:len to:data];
        [data appendBytes:utf8 length:(NSUInteger)len];
    }
}
+ (BOOL)write:(NSString *)str to:(BufferedOutputStream *)os error:(NSError **)error {
    //FIXME: This is really inefficient!
    NSMutableData *data = [[NSMutableData alloc] init];
    [StringIO write:str to:data];
    BOOL ret = [os writeFully:[data bytes] length:[data length] error:error];
    [data release];
    return ret;
}
+ (BOOL)read:(NSString **)value from:(BufferedInputStream *)is error:(NSError **)error {
    if (![StringIO newString:value from:is error:error]) {
        return NO;
    }
    [*value autorelease];
    return YES;
}
+ (BOOL)newString:(NSString **)value from:(BufferedInputStream *)is error:(NSError **)error {
    *value = nil;
    BOOL isNotNil = NO;
    if (![BooleanIO read:&isNotNil from:is error:error]) {
        return NO;
    }
    if (isNotNil) {
        uint64_t len;
        if (![IntegerIO readUInt64:&len from:is error:error]) {
            return NO;
        }
        if (len > 2147483648) {
            SETNSERROR(@"InputStreamErrorDomain", -1, @"absurd string length %llu in [StringIO newString:] from %@", len, is);
            return NO;
        }
        unsigned char *buf = (unsigned char *)malloc((size_t)len);
        *value = nil;
        BOOL ret = [is readExactly:(NSUInteger)len into:buf error:error];
        if (ret) {
            *value = [[NSString alloc] initWithBytes:buf length:(NSUInteger)len encoding:NSUTF8StringEncoding];
        }
        free(buf);
        if (!ret) {
            return NO;
        }
    }
    return YES;
}
@end
