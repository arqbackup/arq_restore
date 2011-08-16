//
//  CryptoKey.m
//  Arq
//
//  Created by Stefan Reitshamer on 6/9/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "CryptoKey.h"
#import "SetNSError.h"
#import "OpenSSL.h"
#import "Encryption.h"

#define ITERATIONS (1000)
#define KEYLEN (48)

@implementation CryptoKey
+ (NSString *)errorDomain {
    return @"CryptoKeyErrorDomain";
}

- (id)init {
    @throw [NSException exceptionWithName:@"InvalidInitializerException" reason:@"can't call CryptoKey init" userInfo:nil];
}
- (id)initWithPassword:(NSString *)thePassword salt:(NSData *)theSalt error:(NSError **)error {
    if (self = [super init]) {
        if (![OpenSSL initializeSSL:error]) {
            [self release];
            return nil;
        }
        if (theSalt != nil && [theSalt length] != 8) {
            SETNSERROR([Encryption errorDomain], -1, @"salt must be 8 bytes or nil");
            [self release];
            return nil;
        }
        cipher = EVP_aes_256_cbc();
        const char *cPassword = [thePassword UTF8String];
        unsigned char *cSaltCopy = NULL;
        if (theSalt != nil) {
            cSaltCopy = (unsigned char *)malloc([theSalt length]);
            memcpy(cSaltCopy, [theSalt bytes], [theSalt length]);
        } else {
            HSLogWarn(@"NULL salt value for CryptoKey");
        }
        unsigned char buf[KEYLEN];
        memset(buf, 0, KEYLEN);
        PKCS5_PBKDF2_HMAC_SHA1(cPassword, strlen(cPassword), cSaltCopy, [theSalt length], ITERATIONS, KEYLEN, buf);
        evpKey[0] = 0;
        EVP_BytesToKey(cipher, EVP_sha1(), cSaltCopy, buf, KEYLEN, ITERATIONS, evpKey, iv);
        if (cSaltCopy != NULL) {
            free(cSaltCopy);
        }
    }
    return self;
}
- (id)initLegacyWithPassword:(NSString *)thePassword error:(NSError **)error {
    if (self = [super init]) {
        if (![OpenSSL initializeSSL:error]) {
            [self release];
            return nil;
        }
        
        cipher = EVP_aes_256_cbc();
        evpKey[0] = 0;
        NSData *passwordData = [thePassword dataUsingEncoding:NSUTF8StringEncoding];        
        EVP_BytesToKey(cipher, EVP_md5(), NULL, [passwordData bytes], [passwordData length], 1, evpKey, iv);
    }
    return self;
}
- (const EVP_CIPHER *)cipher {
    return cipher;
}
- (unsigned char *)evpKey {
    return evpKey;
}
- (unsigned char *)iv {
    return iv;
}
@end
