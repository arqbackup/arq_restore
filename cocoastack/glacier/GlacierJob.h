//
//  GlacierJob.h
//
//  Created by Stefan Reitshamer on 9/17/12.
//
//

@class AWSRegion;


@interface GlacierJob : NSObject {
    AWSRegion *awsRegion;
    NSString *vaultName;
    NSDictionary *json;
}
- (id)initWithAWSRegion:(AWSRegion *)theAWSRegion vaultName:(NSString *)theVaultName json:(NSDictionary *)theJSON;
- (AWSRegion *)awsRegion;
- (NSString *)vaultName;
- (NSString *)jobId;
- (NSString *)action;
- (NSString *)archiveId;
- (NSString *)snsTopicArn;
- (NSDictionary *)json;
@end
