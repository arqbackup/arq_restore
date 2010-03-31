/*
 Copyright (c) 2009, Stefan Reitshamer http://www.haystacksoftware.com
 
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
#import "NSData-Base64Extensions.h"
#import "S3AuthorizationParameters.h"
#import "S3Signature.h"


@implementation S3Signature
+ (NSString *)signatureWithSecretKey:(NSString *)secretKey s3AuthorizationParameters:(S3AuthorizationParameters *)params {
	NSMutableString *buf = [[NSMutableString alloc] init];
	[buf appendString:[params httpVerb]];
	[buf appendString:@"\n"];
	// No Content-MD5
	[buf appendString:@"\n"];
	[buf appendString:[params contentType]];
	[buf appendString:@"\n"];
	[buf appendString:[params date]];
	[buf appendString:@"\n"];
	for (NSString *xamzHeader in [params xamzHeaders]) {
		[buf appendString:xamzHeader];
		[buf appendString:@"\n"];
	}
	if ([[params bucketName] length] > 0) {
		[buf appendString:@"/"];
		[buf appendString:[params bucketName]];
	}
	[buf appendString:[params pathInfo]];
	if ([[params subResource] length] > 0) {
		[buf appendString:[params subResource]];
	}
#if 0
    {
        HSLogDebug(@"string to sign: <%@>", buf);
        const char *stringToSignBytes = [buf UTF8String];
        int stringToSignLen = strlen(stringToSignBytes);
        NSMutableString *displayBytes = [[[NSMutableString alloc] init] autorelease];
        for (int i = 0; i < stringToSignLen; i++) {
            [displayBytes appendString:[NSString stringWithFormat:@"%02x ", stringToSignBytes[i]]];
        }
        HSLogDebug(@"string to sign bytes: <%@>", displayBytes);
    }
#endif
	NSData *clearTextData = [buf dataUsingEncoding:NSUTF8StringEncoding];
	NSData *secretKeyData = [secretKey dataUsingEncoding:NSUTF8StringEncoding];
	[buf release];
	unsigned char digest[CC_SHA1_DIGEST_LENGTH];
	CCHmac(kCCHmacAlgSHA1, [secretKeyData bytes], [secretKeyData length], [clearTextData bytes], [clearTextData length], digest);
	NSData *hmacSHA1 = [[NSData alloc] initWithBytes:digest length:CC_SHA1_DIGEST_LENGTH];
	NSString *base64 = [hmacSHA1 encodeBase64];
	[hmacSHA1 release];
	return base64;
}

@end
