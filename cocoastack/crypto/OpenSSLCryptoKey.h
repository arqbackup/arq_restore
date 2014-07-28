//
//  OpenSSLCryptoKey.h
//  Arq
//
//  Created by Stefan Reitshamer on 10/8/12.
//  Copyright (c) 2012 Stefan Reitshamer. All rights reserved.
//

#ifdef USE_OPENSSL

#include <openssl/evp.h>

@interface OpenSSLCryptoKey : NSObject {
    const EVP_CIPHER *cipher;
    unsigned char evpKey[EVP_MAX_KEY_LENGTH];
    unsigned char iv[EVP_MAX_IV_LENGTH];
}

- (id)initWithPassword:(NSString *)thePassword salt:(NSData *)theSalt error:(NSError **)error;
- (id)initLegacyWithPassword:(NSString *)thePassword error:(NSError **)error;

- (NSData *)encrypt:(NSData *)plainData error:(NSError **)error;
- (NSData *)decrypt:(NSData *)encrypted error:(NSError **)error;

@end

#endif
