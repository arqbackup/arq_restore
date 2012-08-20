//
//  RemoteS3Signer.m
//  Arq
//
//  Created by Stefan Reitshamer on 12/30/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "RemoteS3Signer.h"
#import "HTTPConnection.h"
#import "URLConnection.h"
#import "NSData-InputStream.h"
#import "SetNSError.h"
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
    id <HTTPConnection> conn = [[[URLConnection alloc] initWithURL:url method:@"POST" delegate:nil] autorelease];
    [conn setRequestHeader:accessKey forKey:@"X-Arq-AccessKey"];
    NSData *requestData = [theString dataUsingEncoding:NSUTF8StringEncoding];
    if (![conn executeRequestWithBody:requestData error:error]) {
        return nil;
    }
    id <InputStream> responseBodyStream = [conn newResponseBodyStream:error];
    if (responseBodyStream == nil) {
        return nil;
    }
    NSData *data = [responseBodyStream slurp:error];
    [responseBodyStream release];
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
