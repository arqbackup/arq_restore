//
//  SignatureV2Provider.m
//  Arq
//
//  Created by Stefan Reitshamer on 9/16/12.
//
//

#include <CommonCrypto/CommonHMAC.h>
#import "SignatureV2Provider.h"
#import "NSData-Base64Extensions.h"


@implementation SignatureV2Provider

- (id)initWithSecretKey:(NSString *)theSecretKey {
    if (self = [super init]) {
        secretKeyData = [[theSecretKey dataUsingEncoding:NSUTF8StringEncoding] retain];
    }
    return self;
}
- (void)dealloc {
    [secretKeyData release];
    [super dealloc];
}

- (NSString *)signatureForHTTPMethod:(NSString *)theMethod url:(NSURL *)theURL {
    NSMutableString *stringToSign = [NSMutableString string];
    [stringToSign appendFormat:@"%@\n", theMethod];
    [stringToSign appendFormat:@"%@\n", [[theURL host] lowercaseString]];
    NSString *thePath = [theURL path];
    if ([thePath length] == 0) {
        thePath = @"/";
    }
    [stringToSign appendFormat:@"%@\n", thePath];
    [stringToSign appendString:[theURL query]];
    
    NSData *data = [stringToSign dataUsingEncoding:NSUTF8StringEncoding];
	unsigned char digest[CC_SHA256_DIGEST_LENGTH];
	CCHmac(kCCHmacAlgSHA256, [secretKeyData bytes], [secretKeyData length], [data bytes], [data length], digest);
    NSData *sig = [NSData dataWithBytes:digest length:CC_SHA256_DIGEST_LENGTH];
    return [sig encodeBase64];
}
@end
