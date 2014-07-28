//
//  VaultLister.h
//  Arq
//
//  Created by Stefan Reitshamer on 9/11/12.
//
//

@class GlacierAuthorizationProvider;
@class AWSRegion;


@interface VaultLister : NSObject {
    GlacierAuthorizationProvider *gap;
    AWSRegion *awsRegion;
    BOOL useSSL;
    BOOL retryOnTransientError;
    NSString *marker;
    NSMutableArray *vaults;
}
- (id)initWithGlacierAuthorizationProvider:(GlacierAuthorizationProvider *)theGAP awsRegion:(AWSRegion *)theAWSRegion useSSL:(BOOL)theUseSSL retryOnTransientError:(BOOL)retry;
- (NSArray *)vaults:(NSError **)error;
@end
