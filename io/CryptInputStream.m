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

#import "CryptInputStream.h"
#import "SetNSError.h"
#import "OpenSSL.h"
#import "InputStreams.h"
#import "NSErrorCodes.h"

@interface CryptInputStream (internal)
- (unsigned char *)readAtLeastBlockSize:(NSUInteger *)length error:(NSError **)error;
@end

@implementation CryptInputStream
- (id)initWithCryptInitFunc:(void *)theCryptInit cryptUpdateFunc:(void *)theCryptUpdate cryptFinalFunc:(void *)theCryptFinal inputStream:(id <InputStream>)theIS cipherName:(NSString *)theCipherName key:(NSString *)theKey error:(NSError **)error {
    if (self = [super init]) {
        cryptInit = (CryptInitFunc)theCryptInit;
        cryptUpdate = (CryptUpdateFunc)theCryptUpdate;
        cryptFinal = (CryptFinalFunc)theCryptFinal;
        BOOL ret = NO;
        do {
            is = [theIS retain];
            NSData *keyData = [theKey dataUsingEncoding:NSUTF8StringEncoding];
            if ([keyData length] > EVP_MAX_KEY_LENGTH) {
                SETNSERROR(@"EncryptedInputStreamErrorDomain", -1, @"encryption key must be less than or equal to %d bytes", EVP_MAX_KEY_LENGTH);
                break;
            }
            if (![OpenSSL initializeSSL:error]) {
                break;
            }
            cipher = EVP_get_cipherbyname([theCipherName UTF8String]);
            if (!cipher) {
                SETNSERROR(@"EncryptedInputStreamErrorDomain", -1, @"failed to load %@ cipher: %@", theCipherName, [OpenSSL errorMessage]);
                break;
            }
            evp_key[0] = 0;
            EVP_BytesToKey(cipher, EVP_md5(), NULL, [keyData bytes], [keyData length], 1, evp_key, iv);
            EVP_CIPHER_CTX_init(&cipherContext);
            if (!(*cryptInit)(&cipherContext, cipher, evp_key, iv)) {
                SETNSERROR(@"NSDataEncryptErrorDomain", -1, @"EVP_EncryptInit: %@",  [OpenSSL errorMessage]);
                break;
            }
            EVP_CIPHER_CTX_set_key_length(&cipherContext, EVP_MAX_KEY_LENGTH);
            blockSize = (unsigned long long)EVP_CIPHER_CTX_block_size(&cipherContext);
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
    if (initialized) {
        EVP_CIPHER_CTX_cleanup(&cipherContext);
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
- (unsigned char *)read:(NSUInteger *)length error:(NSError **)error {
    if (finalized) {
        SETNSERROR(@"StreamsErrorDomain", ERROR_EOF, @"already finalized");
        return NULL;
    }
    NSUInteger inLen = 0;
    int outLen = 0;
    NSError *myError;
    unsigned char *inBuf = [self readAtLeastBlockSize:&inLen error:&myError];
    if (inBuf == NULL && [myError code] != ERROR_EOF) {
        if (error != NULL) {
            *error = myError;
        }
        return NULL;
    }
    NSUInteger neededBufLen = inLen + blockSize;
    if (outBufLen < neededBufLen) {
        if (outBuf == NULL) {
            outBuf = (unsigned char *)malloc(neededBufLen);
        } else {
            outBuf = (unsigned char *)realloc(outBuf, neededBufLen);
        }
        outBufLen = neededBufLen;
    }
    if (inBuf != NULL) {
        NSAssert(inLen > 0, @"expected more than 0 input bytes");
        totalInBytesRecvd += inLen;
        if (!(*cryptUpdate)(&cipherContext, outBuf, &outLen, inBuf, inLen)) {
            SETNSERROR(@"OpenSSLErrorDomain", -1, @"crypt update: %@", [OpenSSL errorMessage]);
            return NULL;
        }
        NSAssert(outLen < outBufLen, @"can't receive more bytes than outBufLen from EVP_EncryptUpdate");
    }
    if (outLen == 0) {
        finalized = YES;
        if (totalInBytesRecvd > 0 && !(*cryptFinal)(&cipherContext, outBuf, &outLen)) {
            SETNSERROR(@"OpenSSLErrorDomain", -1, @"crypt final: %@", [OpenSSL errorMessage]);
            return NULL;
        }
        NSAssert(outLen < outBufLen, @"can't receive more bytes than outBufLen from EVP_EncryptFinal");
    }
    if (outLen == 0) {
        SETNSERROR(@"StreamsErrorDomain", ERROR_EOF, @"EOF on encrypted input stream");
        return NULL;
    }
    NSAssert(outLen > 0, @"outLen must be greater than 0");
    *length = (NSUInteger)outLen;
    return outBuf;
}
- (NSData *)slurp:(NSError **)error {
    return [InputStreams slurp:self error:error];
}
- (void)bytesWereNotUsed {
}

@end
@implementation CryptInputStream (internal)
- (unsigned char *)readAtLeastBlockSize:(NSUInteger *)length error:(NSError **)error {
    NSMutableData *data = [NSMutableData data];
    while ([data length] < blockSize) {
        NSUInteger recvd = 0;
        NSError *myError = nil;
        unsigned char *buf = [is read:&recvd error:&myError];
        if (buf == NULL) {
            if ([myError code] != ERROR_EOF) {
                if (error != NULL) {
                    *error = myError;
                }
                return NULL;
            }
            break;
        }
        if (recvd > blockSize && [data length] == 0) {
            // Short-circuit to avoid a buffer copy.
            *length = recvd;
            return buf;
        }
        [data appendBytes:buf length:recvd];
    }
    if ([data length] == 0) {
        SETNSERROR(@"StreamsErrorDomain", ERROR_EOF, @"EOF");
        return NULL;
    }
    NSAssert([data length] > 0, @"must have received some bytes");
    *length = [data length];
    return [data mutableBytes];
}
@end
