/*
 Copyright (c) 2009, Stefan Reitshamer http://www.haystacksoftware.com
 
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

#import "NSString_extra.h"
#import "RegexKitLite.h"

static NSString *PATH_PATTERN = @"^(.+)(\\.\\w+)$";

static unsigned char hexCharToInt(char c1) {
    if (c1 >= '0' && c1 <= '9') {
        return c1 - '0';
    }
    if (c1 >= 'a' && c1 <= 'f') {
        return c1 - 'a' + 10;
    }
    if (c1 >= 'A' && c1 <= 'F') {
        return c1 - 'A' + 10;
    }
    @throw [NSException exceptionWithName:@"Invalid hex char" reason:@"not a hex char" userInfo:nil];
}

@implementation NSString (extra)
+ (NSString *)hexStringWithBytes:(unsigned char *)bytes length:(unsigned int)length {
    char *buf = (char *)malloc(length * 2 + 1);
    for (unsigned int i = 0; i < length; i++) {
        unsigned char c = bytes[i];
        snprintf(buf + i*2, 3, "%02x", (unsigned int)c);
    }
    NSString *ret = [[[NSString alloc] initWithBytes:buf length:length*2 encoding:NSUTF8StringEncoding] autorelease];
    free(buf);
    return ret;
}
- (NSString *)stringWithUniquePath {
    NSString *left = self;
    NSString *right = @"";
    if ([self rangeOfRegex:PATH_PATTERN].location != NSNotFound) {
        left = [self substringWithRange:[self rangeOfRegex:PATH_PATTERN capture:1]];
        right = [self substringWithRange:[self rangeOfRegex:PATH_PATTERN capture:2]];
    }
    NSFileManager *fm = [NSFileManager defaultManager];
    NSUInteger index = 2;
    NSString *path = [NSString stringWithString:self];
    while ([fm fileExistsAtPath:path]) {
        path = [NSString stringWithFormat:@"%@_%u%@", left, index++, right];
    }
    return path;
}
- (NSData *)hexStringToData {
    const char *ascii = [self cStringUsingEncoding:NSASCIIStringEncoding];
    size_t len = strlen(ascii) / 2;
    NSMutableData *data = [NSMutableData dataWithLength:len];
    char *bytes = (char *)[data mutableBytes];
    for (size_t i = 0; i < len; i++) {
        unsigned char c1 = hexCharToInt(ascii[i*2]) << 4;
        unsigned char c2 = hexCharToInt(ascii[i*2 + 1]);
        unsigned char tmp = c1 | c2;
        bytes[i] = tmp;
    }
    return data;
}
@end
