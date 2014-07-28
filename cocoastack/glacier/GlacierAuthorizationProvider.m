//
//  GlacierAuthorizationProvider.m
//
//  Created by Stefan Reitshamer on 9/7/12.
//
//

#import "GlacierAuthorizationProvider.h"
#import "LocalGlacierSigner.h"
#import "HTTPConnection.h"
#import "SHA256Hash.h"
#import "ISO8601Date.h"
#import "GlacierAuthorization.h"


@implementation GlacierAuthorizationProvider
- (id)initWithAccessKey:(NSString *)access secretKey:(NSString *)secret {
    if (self = [super init]) {
        accessKey = [access retain];
        signer = [[LocalGlacierSigner alloc] initWithSecretKey:secret];
    }
    return self;
}
- (void)dealloc {
    [accessKey release];
    [signer release];
    [super dealloc];
}

- (NSString *)authorizationForAWSRegion:(AWSRegion *)theAWSRegion connection:(id <HTTPConnection>)theConn requestBody:(NSData *)theRequestBody {
    GlacierAuthorization *authorization = [[[GlacierAuthorization alloc] initWithAWSRegion:theAWSRegion connection:theConn requestBody:theRequestBody accessKey:accessKey signer:signer] autorelease];
    return [authorization description];
}
@end
