//
//  CryptoKey.h
//
//  Created by Stefan Reitshamer on 6/9/11.
//  Copyright 2011 Haystack Software. All rights reserved.
//

#ifdef USE_OPENSSL
#import "OpenSSLCryptoKey.h"
#else
#import "CCCryptoKey.h"
#endif

@interface CryptoKey : NSObject {
#ifdef USE_OPENSSL
    OpenSSLCryptoKey *cryptoKey;
#else
    CCCryptoKey *cryptoKey;
#endif
}
+ (NSString *)errorDomain;

- (id)initWithPassword:(NSString *)thePassword salt:(NSData *)theSalt error:(NSError **)error;
- (id)initLegacyWithPassword:(NSString *)thePassword error:(NSError **)error;

- (NSData *)encrypt:(NSData *)plainData error:(NSError **)error;
- (NSData *)decrypt:(NSData *)encrypted error:(NSError **)error;
@end
