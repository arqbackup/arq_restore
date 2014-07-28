//
//  Vault.h
//  Arq
//
//  Created by Stefan Reitshamer on 9/7/12.
//
//

@class AWSRegion;
@protocol VaultDelegate;


@interface Vault : NSObject {
    AWSRegion *awsRegion;
    NSDate *creationDate;
    NSDate *lastInventoryDate;
    uint64_t numberOfArchives;
    uint64_t size;
    NSString *vaultARN;
    NSString *vaultName;
}
- (id)initWithAWSRegion:(AWSRegion *)theAWSRegion json:(NSDictionary *)theDict;

- (AWSRegion *)awsRegion;
- (NSDate *)creationDate;
- (NSDate *)lastInventoryDate;
- (uint64_t)numberOfArchives;
- (uint64_t)size;
- (NSString *)vaultARN;
- (NSString *)vaultName;
@end
