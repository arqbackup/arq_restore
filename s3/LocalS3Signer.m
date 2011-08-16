//
//  LocalS3Signer.m
//  Arq
//
//  Created by Stefan Reitshamer on 12/30/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "LocalS3Signer.h"
#include <CommonCrypto/CommonHMAC.h>
#import "NSData-Base64Extensions.h"


@implementation LocalS3Signer
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

#pragma mark S3Signer
- (NSString *)sign:(NSString *)theString error:(NSError **)error {
    NSData *clearTextData = [theString dataUsingEncoding:NSUTF8StringEncoding];
	NSData *secretKeyData = [secretKey dataUsingEncoding:NSUTF8StringEncoding];
	unsigned char digest[CC_SHA1_DIGEST_LENGTH];
	CCHmac(kCCHmacAlgSHA1, [secretKeyData bytes], [secretKeyData length], [clearTextData bytes], [clearTextData length], digest);
	NSData *hmacSHA1 = [[NSData alloc] initWithBytes:digest length:CC_SHA1_DIGEST_LENGTH];
	NSString *base64 = [hmacSHA1 encodeBase64];
	[hmacSHA1 release];
	return base64;
}
@end
