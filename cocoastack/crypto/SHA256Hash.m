//
//  SHA256Hash.m
//  Arq
//
//  Created by Stefan Reitshamer on 9/8/12.
//
//

#import "SHA256Hash.h"
#import <CommonCrypto/CommonDigest.h>


@implementation SHA256Hash
+ (NSData *)hashData:(NSData *)data {
    NSAssert(data != nil, @"data may not be nil!");
    return [SHA256Hash hashBytes:(const unsigned char *)[data bytes] length:[data length]];
}
+ (NSData *)hashBytes:(const unsigned char *)bytes length:(NSUInteger)length {
    unsigned char *digest = (unsigned char *)malloc(CC_SHA256_DIGEST_LENGTH);
    memset(digest, 0, CC_SHA256_DIGEST_LENGTH);
    if (CC_SHA256(bytes, (CC_LONG)length, digest) == NULL) {
        HSLogError(@"CC_SHA256 failed!");
    }
    return [NSData dataWithBytesNoCopy:digest length:CC_SHA256_DIGEST_LENGTH];
}
@end
