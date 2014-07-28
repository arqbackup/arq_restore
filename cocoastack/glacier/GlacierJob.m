//
//  GlacierJob.m
//
//  Created by Stefan Reitshamer on 9/17/12.
//
//

#import "GlacierJob.h"

@implementation GlacierJob
- (id)initWithAWSRegion:(AWSRegion *)theAWSRegion vaultName:(NSString *)theVaultName json:(NSDictionary *)theJSON {
    if (self = [super init]) {
        awsRegion = [theAWSRegion retain];
        vaultName = [theVaultName retain];
        json = [theJSON retain];
    }
    return self;
}
- (void)dealloc {
    [awsRegion release];
    [vaultName release];
    [json release];
    [super dealloc];
}

- (AWSRegion *)awsRegion {
    return awsRegion;
}
- (NSString *)vaultName {
    return vaultName;
}
- (NSString *)jobId {
    return [json objectForKey:@"JobId"];
}
- (NSString *)action {
    return [json objectForKey:@"Action"];
}
- (NSString *)archiveId {
    return [json objectForKey:@"ArchiveId"];
}
- (NSString *)snsTopicArn {
    return [json objectForKey:@"SNSTopic"];
}
- (NSDictionary *)json {
    return json;
}
@end
