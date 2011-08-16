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
#include <openssl/evp.h>
#import "InputStream.h"
@class CryptoKey;

typedef int (*CryptInitFunc)(EVP_CIPHER_CTX *ctx, const EVP_CIPHER *type, unsigned char *key, unsigned char *iv);
typedef int (*CryptUpdateFunc)(EVP_CIPHER_CTX *ctx, unsigned char *out, int *outl, unsigned char *in, int inl);
typedef int (*CryptFinalFunc)(EVP_CIPHER_CTX *ctx, unsigned char *out, int *outl);

@interface CryptInputStream : NSObject <InputStream> {
    CryptInitFunc cryptInit;
    CryptUpdateFunc cryptUpdate;
    CryptFinalFunc cryptFinal;
    id <InputStream> is;
    NSString *label;
    unsigned char *inBuf;
    NSUInteger inBufSize;
    unsigned char *outBuf;
    NSInteger outBufLen;
    NSUInteger outBufSize;
    NSUInteger outBufPos;
    EVP_CIPHER_CTX cipherContext;
    size_t blockSize;
    BOOL initialized;
    BOOL finalized;
}
- (id)initWithCryptInitFunc:(void *)theCryptInit 
            cryptUpdateFunc:(void *)theCryptUpdate 
             cryptFinalFunc:(void *)theCryptFinal 
                inputStream:(id <InputStream>)theIS 
                  cryptoKey:(CryptoKey *)theCryptoKey
                      label:(NSString *)theLabel
                      error:(NSError **)error;
@end
