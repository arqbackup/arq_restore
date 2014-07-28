//
//  LocalGlacierSigner.m
//  Arq
//
//  Created by Stefan Reitshamer on 9/7/12.
//
//

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
