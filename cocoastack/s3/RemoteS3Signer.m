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


#import "RemoteS3Signer.h"
#import "HTTPConnection.h"
#import "HTTPConnectionFactory.h"
#import "NSData-InputStream.h"

#import "HTTP.h"
#import "InputStream.h"


@implementation RemoteS3Signer
+ (NSString *)errorDomain {
    return @"RemoteS3SignerErrorDomain";
}
- (id)initWithAccessKey:(NSString *)theAccessKey url:(NSURL *)theURL account:(NSString *)theAccount password:(NSString *)thePassword {
    if (self = [super init]) {
        accessKey = [theAccessKey retain];
        url = [theURL retain];
        account = [theAccount retain];
        password = [thePassword retain];
    }
    return self;
}
- (void)dealloc {
    [accessKey release];
    [url release];
    [account release];
    [password release];
    [super dealloc];
}


#pragma mark NSCopying
- (id)copyWithZone:(NSZone *)zone {
    return [[RemoteS3Signer alloc] initWithAccessKey:accessKey url:url account:account password:password];
}


#pragma mark S3Signer
- (NSString *)sign:(NSString *)theString error:(NSError **)error {
    id <HTTPConnection> conn = [[[HTTPConnectionFactory theFactory] newHTTPConnectionToURL:url method:@"POST" dataTransferDelegate:nil] autorelease];
    [conn setRequestHeader:accessKey forKey:@"X-Arq-AccessKey"];
    NSData *requestData = [theString dataUsingEncoding:NSUTF8StringEncoding];
    NSData *data = [conn executeRequestWithBody:requestData error:error];
    if (data == nil) {
        return nil;
    }
    int code = [conn responseCode];
    if (code != HTTP_OK) {
        SETNSERROR([RemoteS3Signer errorDomain], -1, @"unexpected HTTP status code %d", code);
        return nil;
    }
    NSString *sig = [[[NSString alloc] initWithBytes:[data bytes] length:[data length] encoding:NSUTF8StringEncoding] autorelease];
    while ([sig hasSuffix:@"\n"]) {
        sig = [sig substringToIndex:([sig length] - 1)];
    }
    HSLogTrace(@"signature: %@", sig);
    return sig;
}
@end
