//
//  CryptoKey.h
//  Arq
//
//  Created by Stefan Reitshamer on 6/9/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#include <openssl/evp.h>


@interface CryptoKey : NSObject {
    const EVP_CIPHER *cipher;
    unsigned char evpKey[EVP_MAX_KEY_LENGTH];
    unsigned char iv[EVP_MAX_IV_LENGTH];
}
+ (NSString *)errorDomain;

- (id)initWithPassword:(NSString *)thePassword salt:(NSData *)theSalt error:(NSError **)error;
- (id)initLegacyWithPassword:(NSString *)thePassword error:(NSError **)error;
- (EVP_CIPHER *)cipher;
- (unsigned char *)evpKey;
- (unsigned char *)iv;
@end
