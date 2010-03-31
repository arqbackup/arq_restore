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

#import "S3Signature.h"
#import "S3AuthorizationProvider.h"


/*
 * WARNING: 
 * This class *must* be reentrant!
 */

@implementation S3AuthorizationProvider
- (id)initWithAccessKey:(NSString *)access secretKey:(NSString *)secret {
	if (self = [super init]) {
        NSAssert(access != nil, @"access key can't be nil");
        NSAssert(secret != nil, @"secret key can't be nil");
		accessKey = [access copy];
		secretKey = [secret copy];
	}
	return self;
}
- (void)dealloc {
	[accessKey release];
	[secretKey release];
	[super dealloc];
}
- (NSString *)accessKey {
	return accessKey;
}
- (NSString *)authorizationForParameters:(S3AuthorizationParameters *)params {
	NSMutableString *buf = [[[NSMutableString alloc] init] autorelease];
	[buf appendString:@"AWS "];
	[buf appendString:accessKey];
	[buf appendString:@":"];
	[buf appendString:[S3Signature signatureWithSecretKey:secretKey s3AuthorizationParameters:params]];
	NSString *ret = [NSString stringWithString:buf];
	if ([ret hasSuffix:@"\n"]) {
		NSUInteger length = [ret length];
		ret = [ret substringToIndex:(length - 1)];
	}
	return ret;
}

@end
