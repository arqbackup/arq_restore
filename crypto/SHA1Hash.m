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

#import "SHA1Hash.h"
#include <openssl/sha.h>
#include <sys/stat.h>
#import "SetNSError.h"
#import "FileInputStream.h"
#import "NSErrorCodes.h"
#import "Blob.h"
#import "BufferedInputStream.h"

#define MY_BUF_SIZE (8192)

@interface SHA1Hash (internal)
+ (NSString *)hashStream:(id <InputStream>)is error:(NSError **)error;
+ (NSString *)hashStream:(id <InputStream>)is streamLength:(unsigned long long *)streamLength error:(NSError **)error;
@end

static NSString *digest2String(unsigned char *digest) {
    char *str = (char *)calloc(SHA_DIGEST_LENGTH, 2);
    for (int i = 0; i < SHA_DIGEST_LENGTH; i++) {
        sprintf(&(str[i*2]), "%02x", digest[i]);
    }
    NSString *ret = [[[NSString alloc] initWithCString:str length:SHA_DIGEST_LENGTH*2] autorelease];
    free(str);
    return ret;
}

@implementation SHA1Hash
+ (NSString *)errorDomain {
    return @"SHA1HashErrorDomain";
}
+ (NSString *)hashData:(NSData *)data {
	SHA_CTX ctx;
	SHA1_Init(&ctx);
	SHA1_Update(&ctx, [data bytes], (unsigned long)[data length]);
	unsigned char md[SHA_DIGEST_LENGTH];
	SHA1_Final(md, &ctx);
    return digest2String(md);
}
+ (NSString *)hashBlob:(Blob *)blob blobLength:(unsigned long long *)blobLength error:(NSError **)error {
    id <InputStream> is = [[blob inputStreamFactory] newInputStream];
    if (is == nil) {
        return nil;
    }
    NSString *sha1 = [SHA1Hash hashStream:is streamLength:blobLength error:error];
    [is release];
    return sha1;
}
+ (NSString *)hashFile:(NSString *)path error:(NSError **)error {
    struct stat st;
    if (lstat([path fileSystemRepresentation], &st) == -1) {
        SETNSERROR(@"UnixErrorDomain", errno, @"lstat(%@): %s", path, strerror(errno));
        return NO;
    }
    unsigned long long length = (unsigned long long)st.st_size;
    FileInputStream *fis = [[FileInputStream alloc] initWithPath:path offset:0 length:length];
    NSString *sha1 = [SHA1Hash hashStream:fis error:error];
    [fis release];
    return sha1;
}
+ (NSString *)hashStream:(id <InputStream>)is withLength:(uint64_t)length error:(NSError **)error {
	SHA_CTX ctx;
	SHA1_Init(&ctx);
    uint64_t received = 0;
    unsigned char *buf = (unsigned char *)malloc(MY_BUF_SIZE);
    NSInteger ret = 0;
    while (received < length) {
        uint64_t toRead = length - received;
        uint64_t toReadThisTime = toRead > MY_BUF_SIZE ? MY_BUF_SIZE : toRead;
        ret = [is read:buf bufferLength:toReadThisTime error:error];
        if (ret < 0) {
            break;
        }
        if (ret == 0) {
            SETNSERROR([SHA1Hash errorDomain], -1, @"unexpected EOF after %qu of %qu bytes", received, length);
            break;
        }
        SHA1_Update(&ctx, buf, ret);
        received += (uint64_t)ret;
    }
    free(buf);
    if (ret <= 0) {
        return nil;
    }
	unsigned char md[SHA_DIGEST_LENGTH];
	SHA1_Final(md, &ctx);
    return digest2String(md);
}
@end

@implementation SHA1Hash (internal)
+ (NSString *)hashStream:(id <InputStream>)is error:(NSError **)error {
    unsigned long long length;
    return [SHA1Hash hashStream:is streamLength:&length error:error];
}
+ (NSString *)hashStream:(id <InputStream>)is streamLength:(unsigned long long *)streamLength error:(NSError **)error {
	SHA_CTX ctx;
	SHA1_Init(&ctx);
    *streamLength = 0;
    unsigned char *buf = (unsigned char *)malloc(MY_BUF_SIZE);
    NSInteger ret = 0;
    for (;;) {
        ret = [is read:buf bufferLength:MY_BUF_SIZE error:error];
        if (ret <= 0) {
            break;
        }
        SHA1_Update(&ctx, buf, (unsigned long)ret);
        *streamLength += (unsigned long long)ret;
    }
    free(buf);
    if (ret < 0) {
        return nil;
    }
	unsigned char md[SHA_DIGEST_LENGTH];
	SHA1_Final(md, &ctx);
    return digest2String(md);
}
@end
