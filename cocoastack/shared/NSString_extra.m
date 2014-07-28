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


#import "NSString_extra.h"
#import "RegexKitLite.h"
#include <openssl/bio.h>
#include <openssl/evp.h>

static const char  table[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

static BOOL isbase64(char c)
{
    return c && strchr(table, c) != NULL;
}

static inline char value(char c)
{
    const char *p = strchr(table, c);
    if(p) {
        return p-table;
    } else {
        return 0;
    }
}

static int UnBase64(unsigned char *dest, const unsigned char *src, int srclen)
{
    *dest = 0;
    if(*src == 0) 
    {
        return 0;
    }
    unsigned char *p = dest;
    do
    {
        
        char a = value(src[0]);
        char b = value(src[1]);
        char c = value(src[2]);
        char d = value(src[3]);
        *p++ = (a << 2) | (b >> 4);
        *p++ = (b << 4) | (c >> 2);
        *p++ = (c << 6) | d;
        if(!isbase64(src[1])) 
        {
            p -= 2;
            break;
        } 
        else if(!isbase64(src[2])) 
        {
            p -= 2;
            break;
        } 
        else if(!isbase64(src[3])) 
        {
            p--;
            break;
        }
        src += 4;
        while(*src && (*src == 13 || *src == 10)) src++;
    }
    while(srclen-= 4);
    *p = 0;
    return (int)(p-dest);
}

static NSString *PATH_PATTERN = @"^(.+)(\\.\\w+)$";

static char hexCharToInt(char c1) {
    if (c1 >= '0' && c1 <= '9') {
        return c1 - '0';
    }
    if (c1 >= 'a' && c1 <= 'f') {
        return c1 - 'a' + 10;
    }
    if (c1 >= 'A' && c1 <= 'F') {
        return c1 - 'A' + 10;
    }
    return -1;
}

@implementation NSString (extra)
+ (NSString *)hexStringWithData:(NSData *)data {
    return [NSString hexStringWithBytes:[data bytes] length:(unsigned int)[data length]];
}
+ (NSString *)hexStringWithBytes:(const unsigned char *)bytes length:(unsigned int)length {
    if (length == 0) {
        return [NSString string];
    }

    char *buf = (char *)malloc(length * 2 + 1);
    for (unsigned int i = 0; i < length; i++) {
        unsigned char c = bytes[i];
        
        unsigned char c1 = (c >> 4) & 0x0f;
        if (c1 > 9) {
            c1 = 'a' + c1 - 10;
        } else {
            c1 = '0' + c1;
        }

        unsigned char c2 = (c & 0xf);
        if (c2 > 9) {
            c2 = 'a' + c2 - 10;
        } else {
            c2 = '0' + c2;
        }
        
        buf[i*2] = c1;
        buf[i*2+1] = c2;
    }
    NSString *ret = [[[NSString alloc] initWithBytes:buf length:length*2 encoding:NSUTF8StringEncoding] autorelease];
    free(buf);
    return ret;
}
+ (NSString *)stringWithRandomUUID {
    CFUUIDRef uuidObj = CFUUIDCreate(nil);//create a new UUID
	NSString *uuidString = (NSString*)CFUUIDCreateString(nil, uuidObj);
	CFRelease(uuidObj);
	return [uuidString autorelease];
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
        path = [NSString stringWithFormat:@"%@_%lu%@", left, (unsigned long)index++, right];
    }
    return path;
}
- (NSData *)hexStringToData:(NSError **)error {
    const char *ascii = [self cStringUsingEncoding:NSASCIIStringEncoding];
    size_t len = strlen(ascii) / 2;
    NSMutableData *data = [NSMutableData dataWithLength:len];
    char *bytes = (char *)[data mutableBytes];
    for (size_t i = 0; i < len; i++) {
        char c1 = hexCharToInt(ascii[i*2]);
        char c2 = hexCharToInt(ascii[i*2 + 1]);
        if (c1 < 0 || c2 < 0) {
            SETNSERROR(@"NSStringExtraErrorDomain", -1, @"invalid hex string %@", self);
            return nil;
        }
        unsigned char tmp = ((unsigned char)c1 << 4) | (unsigned char)c2;
        bytes[i] = tmp;
    }
    return data;
}
- (NSData *)decodeBase64 {
    NSData *encodedData = [self dataUsingEncoding:NSASCIIStringEncoding];
    const unsigned char *encoded = (const unsigned char *)[encodedData bytes];
    unsigned char *decoded = (unsigned char *)malloc([encodedData length]);
    int ret = UnBase64(decoded, encoded, (int)[encodedData length]);
    NSData *decodedData = [[[NSData alloc] initWithBytes:decoded length:ret] autorelease];
    free(decoded);
    return decodedData;
}
- (NSComparisonResult)compareByLength:(NSString *)value {
    NSUInteger myLength = [self length];
    NSUInteger otherLength = [value length];
    if (myLength == otherLength) {
        return [self compare:value];
    }
    if (myLength < otherLength) {
        return NSOrderedAscending;
    }
    return NSOrderedDescending;
}
- (NSString *)stringByEscapingURLCharacters {
    return [(NSString *)CFURLCreateStringByAddingPercentEscapes(NULL,
                                                                (CFStringRef)self,
                                                                NULL,
                                                                (CFStringRef)@"!*'();:@&=+$,/?%#[]",
                                                                kCFStringEncodingUTF8) autorelease];
}
- (NSString *)stringByDeletingTrailingSlash {
    if ([self isEqualToString:@"/"] || ![self hasSuffix:@"/"]) {
        return self;
    }
    return [self substringToIndex:[self length] - 1];
}
@end
