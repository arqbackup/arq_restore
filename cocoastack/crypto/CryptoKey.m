//
//  CryptoKey.m
//  Arq
//
//  Created by Stefan Reitshamer on 6/9/11.
//  Copyright 2011 Haystack Software. All rights reserved.
//

#import "CryptoKey.h"

#ifdef USE_OPENSSL
#import "OpenSSLCryptoKey.h"
#else
#import "CCCryptoKey.h"
#endif


@implementation CryptoKey
+ (NSString *)errorDomain {
    return @"CryptoKeyErrorDomain";
}

- (id)init {
    @throw [NSException exceptionWithName:@"InvalidInitializerException" reason:@"can't call CryptoKey init" userInfo:nil];
}
- (id)initWithPassword:(NSString *)thePassword salt:(NSData *)theSalt error:(NSError **)error {
    if (self = [super init]) {
        if ([thePassword length] == 0) {
            SETNSERROR([CryptoKey errorDomain], ERROR_NOT_FOUND, @"missing encryption password");
            [self release];
            return nil;
        }

#ifdef USE_OPENSSL
        cryptoKey = [[OpenSSLCryptoKey alloc] initWithPassword:thePassword salt:theSalt error:error];
        HSLogDebug(@"using OpenSSL");
#else
        cryptoKey = [[CCCryptoKey alloc] initWithPassword:thePassword salt:theSalt error:error];
        HSLogDebug(@"using CommonCrypto");
#endif
        if (cryptoKey == nil) {
            [self release];
            return nil;
        }
    }
    return self;
}
- (id)initLegacyWithPassword:(NSString *)thePassword error:(NSError **)error {
    if (self = [super init]) {
        if ([thePassword length] == 0) {
            SETNSERROR([CryptoKey errorDomain], ERROR_NOT_FOUND, @"missing encryption password");
            [self release];
            return nil;
        }

#ifdef USE_OPENSSL
        cryptoKey = [[OpenSSLCryptoKey alloc] initLegacyWithPassword:thePassword error:error];
#else
        cryptoKey = [[CCCryptoKey alloc] initLegacyWithPassword:thePassword error:error];
#endif
        if (cryptoKey == nil) {
            [self release];
            return nil;
        }
    }
    return self;
}
- (void)dealloc {
    [cryptoKey release];
    [super dealloc];
}
- (NSData *)encrypt:(NSData *)plainData error:(NSError **)error {
    return [cryptoKey encrypt:plainData error:error];
}
- (NSData *)decrypt:(NSData *)encrypted error:(NSError **)error {
    return [cryptoKey decrypt:encrypted error:error];
}
@end
