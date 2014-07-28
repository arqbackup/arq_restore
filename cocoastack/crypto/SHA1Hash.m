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

#import <CommonCrypto/CommonDigest.h>
#include <sys/stat.h>
#import "SHA1Hash.h"
#import "NSString_extra.h"
#import "FileInputStream.h"
#import "BufferedInputStream.h"


#define MY_BUF_SIZE (4096)

@interface SHA1Hash (internal)
+ (NSString *)hashStream:(id <InputStream>)is error:(NSError **)error;
+ (NSString *)hashStream:(id <InputStream>)is streamLength:(unsigned long long *)streamLength error:(NSError **)error;
+ (NSString *)hashPhotoStream:(BufferedInputStream *)bis totalLength:(unsigned long long)totalLength error:(NSError **)error;
+ (BOOL)updateSHA1:(CC_SHA1_CTX *)ctx fromStream:(id <InputStream>)is length:(unsigned long long)theLength error:(NSError **)error;
@end


@implementation SHA1Hash
+ (NSString *)errorDomain {
    return @"SHA1HashErrorDomain";
}
+ (NSString *)hashData:(NSData *)data {
    unsigned char digest[CC_SHA1_DIGEST_LENGTH];
    memset(digest, 0, CC_SHA1_DIGEST_LENGTH);
    if (CC_SHA1([data bytes], (CC_LONG)[data length], digest) == NULL) {
        HSLogError(@"CC_SHA1 failed!");
    }
    return [NSString hexStringWithBytes:digest length:CC_SHA1_DIGEST_LENGTH];
}
+ (NSString *)hashFile:(NSString *)path error:(NSError **)error {
    struct stat st;
    if (lstat([path fileSystemRepresentation], &st) == -1) {
        int errnum = errno;
        HSLogError(@"lstat(%@) error %d: %s", path, errnum, strerror(errnum));
        SETNSERROR(@"UnixErrorDomain", errnum, @"%@: %s", path, strerror(errnum));
        return NO;
    }
    unsigned long long length = (unsigned long long)st.st_size;
    FileInputStream *fis = [[FileInputStream alloc] initWithPath:path offset:0 length:length];
    NSString *sha1 = [SHA1Hash hashStream:fis error:error];
    [fis release];
    return sha1;
}
+ (NSString *)hashStream:(id <InputStream>)is withLength:(uint64_t)length error:(NSError **)error {
    CC_SHA1_CTX ctx;
    CC_SHA1_Init(&ctx);
    uint64_t received = 0;
    unsigned char *buf = (unsigned char *)malloc(MY_BUF_SIZE);
    NSInteger ret = 0;
    while (received < length) {
        uint64_t toRead = length - received;
        uint64_t toReadThisTime = toRead > MY_BUF_SIZE ? MY_BUF_SIZE : toRead;
        ret = [is read:buf bufferLength:(NSUInteger)toReadThisTime error:error];
        if (ret < 0) {
            break;
        }
        if (ret == 0) {
            SETNSERROR([SHA1Hash errorDomain], ERROR_EOF, @"unexpected EOF in %@ after %qu of %qu bytes", is, received, length);
            break;
        }
        CC_SHA1_Update(&ctx, buf, (CC_LONG)ret);
        received += (uint64_t)ret;
    }
    free(buf);
    if (ret < 0) {
        return nil;
    }
	unsigned char digest[CC_SHA1_DIGEST_LENGTH];
    CC_SHA1_Final(digest, &ctx);
    return [NSString hexStringWithBytes:digest length:CC_SHA1_DIGEST_LENGTH];
}
+ (NSString *)hashPhoto:(NSString *)path error:(NSError **)error {
    struct stat st;
    if (lstat([path fileSystemRepresentation], &st) == -1) {
        int errnum = errno;
        HSLogError(@"lstat(%@) error %d: %s", path, errnum, strerror(errnum));
        SETNSERROR(@"UnixErrorDomain", errnum, @"%@: %s", path, strerror(errnum));
        return nil;
    }
    unsigned long long totalLength = (unsigned long long)st.st_size;
    FileInputStream *fis = [[FileInputStream alloc] initWithPath:path offset:0 length:totalLength];
    BufferedInputStream *bis = [[BufferedInputStream alloc] initWithUnderlyingStream:fis];
    [fis release];
    NSString *sha1 = [SHA1Hash hashPhotoStream:bis totalLength:totalLength error:error];
    [bis release];
    if (sha1 == nil) {
        sha1 = [SHA1Hash hashFile:path error:error];
    }
    return sha1;
}
@end

@implementation SHA1Hash (internal)
+ (NSString *)hashStream:(id <InputStream>)is error:(NSError **)error {
    unsigned long long length;
    return [SHA1Hash hashStream:is streamLength:&length error:error];
}
+ (NSString *)hashStream:(id <InputStream>)is streamLength:(unsigned long long *)streamLength error:(NSError **)error {
    CC_SHA1_CTX ctx;
    CC_SHA1_Init(&ctx);
    *streamLength = 0;
    unsigned char *buf = (unsigned char *)malloc(MY_BUF_SIZE);
    NSInteger ret = 0;
    for (;;) {
        ret = [is read:buf bufferLength:MY_BUF_SIZE error:error];
        if (ret <= 0) {
            break;
        }
        CC_SHA1_Update(&ctx, buf, (CC_LONG)ret);
        *streamLength += (unsigned long long)ret;
    }
    free(buf);
    if (ret < 0) {
        return nil;
    }
	unsigned char md[CC_SHA1_DIGEST_LENGTH];
	CC_SHA1_Final(md, &ctx);
    return [NSString hexStringWithBytes:md length:CC_SHA1_DIGEST_LENGTH];
}
+ (NSString *)hashPhotoStream:(BufferedInputStream *)bis totalLength:(unsigned long long)totalLength error:(NSError **)error {
    CC_SHA1_CTX ctx;
    CC_SHA1_Init(&ctx);
    uint64_t received = 0;
    if (totalLength > 4) {
        unsigned char buf[2];
        if (![bis readExactly:2 into:buf error:error]) {
            return nil;
        }
        received += 2;
        if (buf[0] == 0xff && buf[1] == 0xd8) {
            // It's a JPEG. Skip the metadata.
            for (;;) {
                if (![bis readExactly:2 into:buf error:error]) {
                    return nil;
                }
                received += 2;
                unsigned int markerID = ((unsigned int)buf[0] << 8) + (unsigned int)buf[1];
                NSAssert(received <= totalLength, @"received can't be greater than totalLength");
                if (received == totalLength) {
                    if (markerID != 0xffd9) {
                        HSLogWarn(@"unexpected end marker in JPEG: 0x%04x", markerID);
                    }
                    break;
                }
                if (![bis readExactly:2 into:buf error:error]) {
                    return nil;
                }
                received += 2;
                uint32_t segmentLength = ((uint32_t)buf[0] << 8) + (uint32_t)buf[1];
                if (markerID == 0xffda) {
                    // Read in the rest of the file minus the last 2 bytes.
                    if (![self updateSHA1:&ctx fromStream:bis length:(totalLength - 2 - received) error:error]) {
                        return nil;
                    }
                    received = totalLength - 2;
                } else {
                    if (segmentLength < 3) {
                        SETNSERROR([SHA1Hash errorDomain], -1, @"%@: JPEG segment %04x length can't be fewer than 3 bytes long", bis, (unsigned int)markerID);
                        return nil;
                    }
                    NSData *data = [bis readExactly:(segmentLength - 2) error:error];
                    if (data == nil) {
                        return nil;
                    }
                    received += segmentLength - 2;
                }
            }
        } else {
            CC_SHA1_Update(&ctx, buf, 2);
        }
    }
    unsigned char *buf = (unsigned char *)malloc(MY_BUF_SIZE);
    NSInteger ret = 0;
    while (received < totalLength) {
        uint64_t needed = totalLength - received;
        int64_t toRead = needed > MY_BUF_SIZE ? MY_BUF_SIZE : needed;
        ret = [bis read:buf bufferLength:(NSUInteger)toRead error:error];
        if (ret <= 0) {
            break;
        }
        CC_SHA1_Update(&ctx, buf, (CC_LONG)ret);
        received += (uint64_t)ret;
    }
    free(buf);
    if (ret < 0) {
        return nil;
    }
	unsigned char md[CC_SHA1_DIGEST_LENGTH];
	CC_SHA1_Final(md, &ctx);
    return [NSString hexStringWithBytes:md length:CC_SHA1_DIGEST_LENGTH];
}
+ (BOOL)updateSHA1:(CC_SHA1_CTX *)ctx fromStream:(id <InputStream>)is length:(unsigned long long)theLength error:(NSError **)error {
    unsigned char *imageBuf = (unsigned char *)malloc(MY_BUF_SIZE);
    uint64_t recvd = 0;
    NSInteger ret = 0;
    while (recvd < theLength) {
        uint64_t needed = theLength - recvd;
        uint64_t toRead = needed > MY_BUF_SIZE ? MY_BUF_SIZE : needed;
        ret = [is read:imageBuf bufferLength:(NSUInteger)toRead error:error];
        if (ret < 0) {
            break;
        }
        if (ret == 0) {
            SETNSERROR([SHA1Hash errorDomain], -1, @"unexpected EOF reading image data from %@", is);
            break;
        }
        CC_SHA1_Update(ctx, imageBuf, (CC_LONG)ret);
        recvd += (uint64_t)ret;
    }
    free(imageBuf);
    return ret > 0;
}
@end
