//
//  GlacierJobLister.h
//
//  Created by Stefan Reitshamer on 9/17/12.
//
//

@class GlacierAuthorizationProvider;
@class AWSRegion;


@interface GlacierJobLister : NSObject {
    GlacierAuthorizationProvider *gap;
    NSString *vaultName;
    AWSRegion *awsRegion;
    BOOL useSSL;
    BOOL retryOnTransientError;
    NSString *marker;
    NSMutableArray *jobs;
}
- (id)initWithGlacierAuthorizationProvider:(GlacierAuthorizationProvider *)theGAP vaultName:(NSString *)theVaultName awsRegion:(AWSRegion *)theAWSRegion useSSL:(BOOL)theUseSSL retryOnTransientError:(BOOL)retry;
- (NSArray *)jobs:(NSError **)error;
@end
