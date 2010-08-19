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

#import <openssl/evp.h>

#import "NSData-Encrypt.h"
#import "OpenSSL.h"
#import "SetNSError.h"

@interface Crypter : NSObject {
    NSData *data;
    const EVP_CIPHER *cipher;
    EVP_CIPHER_CTX cipherContext;
    unsigned char evp_key[EVP_MAX_KEY_LENGTH];
    unsigned char iv[EVP_MAX_IV_LENGTH];
}
- (id)initWithCipher:(NSString *)cipherName key:(NSString *)key data:(NSData *)theData error:(NSError **)error;
- (NSData *)encrypt:(NSError **)error;
- (NSData *)decrypt:(NSError **)error;
@end

@implementation Crypter 
- (id)initWithCipher:(NSString *)cipherName key:(NSString *)key data:(NSData *)theData error:(NSError **)error {
    if (self = [super init]) {
        BOOL ret = NO;
        do {
            data = [theData retain];
            if ([data length] > 0) {
                NSData *keyData = [key dataUsingEncoding:NSUTF8StringEncoding];
                if ([keyData length] > EVP_MAX_KEY_LENGTH) {
                    SETNSERROR([NSData encryptErrorDomain], -1, @"encryption key must be less than or equal to %d bytes", EVP_MAX_KEY_LENGTH);
                    break;
                }
                if (![OpenSSL initializeSSL:error]) {
                    break;
                }
                cipher = EVP_get_cipherbyname([cipherName UTF8String]);
                if (!cipher) {
                    SETNSERROR([NSData encryptErrorDomain], -1, @"failed to load %@ cipher: %@", cipherName, [OpenSSL errorMessage]);
                    break;
                }
                
                evp_key[0] = 0;
                EVP_BytesToKey(cipher, EVP_md5(), NULL, [keyData bytes], [keyData length], 1, evp_key, iv);
                
                EVP_CIPHER_CTX_init(&cipherContext);
            }
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
    if ([data length] > 0) {
        EVP_CIPHER_CTX_cleanup(&cipherContext);
    }
    [data release];
    [super dealloc];
}
- (NSData *)encrypt:(NSError **)error {
    if ([data length] == 0) {
        return [NSData data];
    }
    
    if (!EVP_EncryptInit(&cipherContext, cipher, evp_key, iv)) {
        SETNSERROR([NSData encryptErrorDomain], -1, @"EVP_EncryptInit: %@",  [OpenSSL errorMessage]);
        return nil;
    }
    EVP_CIPHER_CTX_set_key_length(&cipherContext, EVP_MAX_KEY_LENGTH);
    
    // Need room for data + cipher block size - 1.
    unsigned char *outbuf = (unsigned char *)calloc([data length] + EVP_CIPHER_CTX_block_size(&cipherContext) - 1, sizeof(unsigned char));
    
    int outlen;
    if (!EVP_EncryptUpdate(&cipherContext, outbuf, &outlen, [data bytes], [data length])) {
        SETNSERROR([NSData encryptErrorDomain], -1, @"EVP_EncryptUpdate: %@",  [OpenSSL errorMessage]);
        return nil;
    }
    int templen;
    if (!EVP_EncryptFinal(&cipherContext, outbuf + outlen, &templen)) {
        SETNSERROR([NSData encryptErrorDomain], -1, @"EVP_EncryptFinal: %@",  [OpenSSL errorMessage]);
        return nil;
    }
    outlen += templen;
    NSData *ret = [[[NSData alloc] initWithBytes:outbuf length:outlen] autorelease];
    free(outbuf);
    return ret;
}
- (NSData *)decrypt:(NSError **)error {
    if ([data length] == 0) {
        return [NSData data];
    }
    
    int inlen = [data length];
    unsigned char *input = (unsigned char *)[data bytes];
    
    // Check for 8-byte salt in encrypted data and skip it.
    if (inlen > 8+8 && strncmp((const char *)input, "Salted__", 8) == 0) {
        input += 16;
        inlen -= 16;
    }
    
    if (!EVP_DecryptInit(&cipherContext, cipher, evp_key, iv)) {
        SETNSERROR([NSData decryptErrorDomain], -1, @"EVP_DecryptInit: %@", [OpenSSL errorMessage]);
        return nil;
    }
    EVP_CIPHER_CTX_set_key_length(&cipherContext, EVP_MAX_KEY_LENGTH);
    
    // The data buffer passed to EVP_DecryptUpdate() should have sufficient room for
    // (input_length + cipher_block_size) bytes unless the cipher block size is 1 in which
    // case input_length bytes is sufficient.
    unsigned char *outbuf;
    if(EVP_CIPHER_CTX_block_size(&cipherContext) > 1) {
        outbuf = (unsigned char *)calloc(inlen + EVP_CIPHER_CTX_block_size(&cipherContext), sizeof(unsigned char));
    } else {
        outbuf = (unsigned char *)calloc(inlen, sizeof(unsigned char));
    }
    
    int outlen;
    if (!EVP_DecryptUpdate(&cipherContext, outbuf, &outlen, input, inlen)) {
        SETNSERROR([NSData decryptErrorDomain], -1, @"EVP_DecryptUpdate: %@", [OpenSSL errorMessage]);
        return nil;
    }
    int templen;
    if (!EVP_DecryptFinal(&cipherContext, outbuf + outlen, &templen)) {
        SETNSERROR([NSData decryptErrorDomain], -1, @"EVP_DecryptFinal: %@", [OpenSSL errorMessage]);
        return nil;
    }
    outlen += templen;
    NSData *ret = [[[NSData alloc] initWithBytes:outbuf length:outlen] autorelease];
    free(outbuf);
    return ret;
}
@end

@implementation NSData (Encrypt)
+ (NSString *)encryptErrorDomain {
    return @"NSDataEncryptErrorDomain";
}
+ (NSString *)decryptErrorDomain {
    return @"NSDataDecryptErrorDomain";
}
- (NSData *)encryptWithCipher:(NSString *)cipherName key:(NSString *)key error:(NSError **)error {
    NSData *ret = nil;
    Crypter *crypter = [[Crypter alloc] initWithCipher:cipherName key:key data:self error:error];
    if (crypter != nil) {
        ret = [crypter encrypt:error];
        [crypter release];
    }
    return ret;
}

- (NSData *)decryptWithCipher:(NSString *)cipherName key:(NSString *)key error:(NSError **)error {    
    NSData *ret = nil;
    Crypter *crypter = [[Crypter alloc] initWithCipher:cipherName key:key data:self error:error];
    if (crypter != nil) {
        ret = [crypter decrypt:error];
        [crypter release];
    }
    return ret;
}

@end
