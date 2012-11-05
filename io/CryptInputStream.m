/*
 Copyright (c) 2009-2011, Stefan Reitshamer http://www.haystacksoftware.com
 
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

#import <Cocoa/Cocoa.h>

#import "CryptInputStream.h"
#import "SetNSError.h"
#import "OpenSSL.h"
#import "InputStreams.h"
#import "NSErrorCodes.h"
#import "CryptoKey.h"
#import "Encryption.h"

#define MY_BUF_SIZE (4096)

@interface CryptInputStream (internal)
- (BOOL)fillOutBuf:(NSError **)error;
@end

@implementation CryptInputStream
- (id)initWithCryptInitFunc:(void *)theCryptInit 
            cryptUpdateFunc:(void *)theCryptUpdate 
             cryptFinalFunc:(void *)theCryptFinal 
                inputStream:(id <InputStream>)theIS 
                  cryptoKey:(CryptoKey *)theCryptoKey
                      label:(NSString *)theLabel
                      error:(NSError **)error {
    if (self = [super init]) {
        label = [theLabel retain];
        cryptInit = (CryptInitFunc)theCryptInit;
        cryptUpdate = (CryptUpdateFunc)theCryptUpdate;
        cryptFinal = (CryptFinalFunc)theCryptFinal;
        BOOL ret = NO;
        do {
            is = [theIS retain];
            EVP_CIPHER_CTX_init(&cipherContext);
            if (!(*cryptInit)(&cipherContext, [theCryptoKey cipher], [theCryptoKey evpKey], [theCryptoKey iv])) {
                SETNSERROR([Encryption errorDomain], -1, @"%@ initialization error: %@",  label, [OpenSSL errorMessage]);
                break;
            }
            EVP_CIPHER_CTX_set_key_length(&cipherContext, EVP_MAX_KEY_LENGTH);
            blockSize = (unsigned long long)EVP_CIPHER_CTX_block_size(&cipherContext);
            inBufSize = MY_BUF_SIZE;
            inBuf = (unsigned char *)malloc(inBufSize);
            outBufSize = MY_BUF_SIZE + blockSize - 1;
            outBuf = (unsigned char *)malloc(outBufSize);
            initialized = YES;
            ret = YES;
        } while(0);
        if (!ret) {
            [self release];
            self = nil;
        }
    }
    return self;
}
- (void)dealloc {
    [label release];
    if (initialized) {
        EVP_CIPHER_CTX_cleanup(&cipherContext);
    }
    if (inBuf != NULL) {
        free(inBuf);
    }
    if (outBuf != NULL) {
        free(outBuf);
    }
    [is release];
    [super dealloc];
}
- (BOOL)cryptUpdate:(int *)outLen inBuf:(unsigned char *)inBuf inLen:(NSUInteger)inLen {
    @throw [NSException exceptionWithName:@"PureVirtualMethod" reason:@"don't call this" userInfo:nil];
}
- (BOOL)cryptFinal:(int *)outLen {
    @throw [NSException exceptionWithName:@"PureVirtualMethod" reason:@"don't call this" userInfo:nil];
}

#pragma mark InputStream
- (NSInteger)read:(unsigned char *)buf bufferLength:(NSUInteger)bufferLength error:(NSError **)error {
    while (outBufPos >= outBufLen && !finalized) {
        if (![self fillOutBuf:error]) {
            return -1;
        }
    }
    NSUInteger available = outBufLen - outBufPos;
    NSUInteger ret = 0;
    if (available > 0) {
        NSUInteger toCopy = available > bufferLength ? bufferLength : available;
        memcpy(buf, outBuf + outBufPos, toCopy);
        outBufPos += toCopy;
        ret = toCopy;
    }
    return ret;
}
- (NSData *)slurp:(NSError **)error {
    return [InputStreams slurp:self error:error];
}
@end

@implementation CryptInputStream (internal)
- (BOOL)fillOutBuf:(NSError **)error {
    if (finalized) {
        SETNSERROR([Encryption errorDomain], ERROR_EOF, @"EOF");
        return NO;
    }
    outBufLen = 0;
    outBufPos = 0;
    NSInteger recvd = [is read:inBuf bufferLength:inBufSize error:error];
    if (recvd == -1) {
        return NO;
    }
    if (recvd == 0) {
        finalized = YES;
        int theBufLen = 0;
        if (!(cryptFinal)(&cipherContext, outBuf, &theBufLen)) {
            SETNSERROR([Encryption errorDomain], -1, @"%@ error: %@", label, [OpenSSL errorMessage]);
            return NO;
        }
        HSLogTrace(@"%@ final: outBufLen = %ld", label, (NSInteger)outBufLen);
        outBufLen = (NSInteger)theBufLen;
    } else {
        int theBufLen = 0;
        if (!(*cryptUpdate)(&cipherContext, outBuf, &theBufLen, inBuf, recvd)) {
            SETNSERROR([Encryption errorDomain], -1, @"%@ error: %@", label, [OpenSSL errorMessage]);
            return NO;
        }
        HSLogTrace(@"%@ update: inBufLen = %ld, outBufLen = %ld", label, recvd, (NSInteger)outBufLen);
        outBufLen = (NSInteger)theBufLen;
    }
    return YES;
}
@end
