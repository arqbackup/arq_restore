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
