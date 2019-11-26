/*
 Copyright (c) 2009-2017, Haystack Software LLC https://www.arqbackup.com
 
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



#import "LocalGlacierSigner.h"
#include <CommonCrypto/CommonHMAC.h>
#import "NSData-Base64Extensions.h"
#import "NSString_extra.h"

#define TERMINATOR (@"aws4_request")

@interface LocalGlacierSigner ()
- (NSData *)signString:(NSString *)theString withKey:(NSData *)theKey;
@end

@implementation LocalGlacierSigner
- (id)initWithSecretKey:(NSString *)theSecretKey {
    if (self = [super init]) {
        secretKey = [theSecretKey retain];
    }
    return self;
}
- (void)dealloc {
    [secretKey release];
    [super dealloc];
}


#pragma mark GlacierSigner
- (NSString *)signString:(NSString *)theStringToSign withDateStamp:(NSString *)theDateStamp regionName:(NSString *)theRegionName serviceName:(NSString *)theServiceName {
    // FIXME: Extract region name from endpoint.
    // FIXME: Extract service name from endpoint.
    
    NSData *secret = [[NSString stringWithFormat:@"AWS4%@", secretKey] dataUsingEncoding:NSUTF8StringEncoding];
    NSData *date = [self signString:theDateStamp withKey:secret];
    NSData *region = [self signString:theRegionName withKey:date];
    NSData *service = [self signString:@"glacier" withKey:region];
    NSData *signing = [self signString:TERMINATOR withKey:service];
    NSData *signature = [self signString:theStringToSign withKey:signing];
    NSString *ret = [NSString hexStringWithBytes:[signature bytes] length:(unsigned int)[signature length]];
    return ret;
}


#pragma mark internal
- (NSData *)signString:(NSString *)theString withKey:(NSData *)theKey {
    NSData *data = [theString dataUsingEncoding:NSUTF8StringEncoding];
	unsigned char digest[CC_SHA256_DIGEST_LENGTH];
	CCHmac(kCCHmacAlgSHA256, [theKey bytes], [theKey length], [data bytes], [data length], digest);
    return [NSData dataWithBytes:digest length:CC_SHA256_DIGEST_LENGTH];
}
@end
