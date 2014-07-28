//
//  RemoteS3Signer.m
//  Arq
//
//  Created by Stefan Reitshamer on 12/30/10.
//  Copyright 2010 Haystack Software. All rights reserved.
//

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
