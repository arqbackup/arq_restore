/*
 Copyright (c) 2009-2014, Stefan Reitshamer http://www.haystacksoftware.com
 
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
