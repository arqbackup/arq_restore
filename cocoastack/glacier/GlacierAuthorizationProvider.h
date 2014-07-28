//
//  GlacierAuthorizationProvider.h
//
//  Created by Stefan Reitshamer on 9/7/12.
//
//

@protocol GlacierSigner;
@protocol HTTPConnection;
@class AWSRegion;


@interface GlacierAuthorizationProvider : NSObject {
    NSString *accessKey;
    id <GlacierSigner> signer;
}
- (id)initWithAccessKey:(NSString *)access secretKey:(NSString *)secret;
- (NSString *)authorizationForAWSRegion:(AWSRegion *)theAWSRegion connection:(id <HTTPConnection>)theConn requestBody:(NSData *)theRequestBody;
@end
