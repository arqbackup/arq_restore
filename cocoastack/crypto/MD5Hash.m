//
//  MD5Hash.m
//  Arq
//
//  Created by Stefan Reitshamer on 1/1/14.
//  Copyright (c) 2014 Stefan Reitshamer. All rights reserved.
//

#import <CommonCrypto/CommonDigest.h>
#import "MD5Hash.h"
#import "NSString_extra.h"
#import "NSData-Base64Extensions.h"


@implementation MD5Hash
+ (NSString *)hashDataBase64Encode:(NSData *)data {
    unsigned char digest[CC_MD5_DIGEST_LENGTH];
    memset(digest, 0, CC_MD5_DIGEST_LENGTH);
    if (CC_MD5([data bytes], (CC_LONG)[data length], digest) == NULL) {
        HSLogError(@"CC_MD5 failed!");
    }
    NSData *digestData = [NSData dataWithBytes:digest length:CC_MD5_DIGEST_LENGTH];
    return [digestData encodeBase64];
}
@end
