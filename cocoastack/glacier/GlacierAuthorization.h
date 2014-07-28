//
//  GlacierAuthorization.h
//
//  Created by Stefan Reitshamer on 9/8/12.
//
//

@class AWSRegion;
@protocol HTTPConnection;
@protocol GlacierSigner;


@interface GlacierAuthorization : NSObject {
    AWSRegion *awsRegion;
    id <HTTPConnection> conn;
    NSData *requestBody;
    NSString *accessKey;
    id <GlacierSigner> signer;
}
- (id)initWithAWSRegion:(AWSRegion *)theAWSRegion connection:(id <HTTPConnection>)theConn requestBody:(NSData *)theRequestBody accessKey:(NSString *)theAccessKey signer:(id <GlacierSigner>)theSigner;
@end
