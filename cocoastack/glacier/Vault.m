//
//  Vault.m
//  Arq
//
//  Created by Stefan Reitshamer on 9/7/12.
//
//

#import "Vault.h"
#import "ISO8601Date.h"


@implementation Vault
- (id)initWithAWSRegion:(AWSRegion *)theAWSRegion json:(NSDictionary *)theDict {
    if (self = [super init]) {
        awsRegion = [theAWSRegion retain];
        NSString *theCreationDate = [theDict objectForKey:@"CreationDate"];
        if (theCreationDate != nil && ![theCreationDate isKindOfClass:[NSNull class]]) {
            NSError *myError = nil;
            creationDate = [[ISO8601Date dateFromString:theCreationDate error:&myError] retain];
            if (creationDate == nil) {
                HSLogError(@"%@", myError);
            }
        }
        
        NSString *theLastInventoryDate = [theDict objectForKey:@"LastInventoryDate"];
        if (theLastInventoryDate != nil && ![theLastInventoryDate isKindOfClass:[NSNull class]]) {
            NSError *myError = nil;
            lastInventoryDate = [[ISO8601Date dateFromString:theLastInventoryDate error:&myError] retain];
            if (lastInventoryDate == nil) {
                HSLogError(@"%@", myError);
            }
        }
        
        vaultARN = [[theDict objectForKey:@"VaultARN"] retain];
        vaultName = [[theDict objectForKey:@"VaultName"] retain];
        numberOfArchives = (uint64_t)[[theDict objectForKey:@"NumberOfArchives"] unsignedLongLongValue];
        size = (uint64_t)[[theDict objectForKey:@"SizeInBytes"] unsignedLongLongValue];
    }
    return self;
}
- (void)dealloc {
    [awsRegion release];
    [creationDate release];
    [lastInventoryDate release];
    [vaultARN release];
    [vaultName release];
    [super dealloc];
}

- (AWSRegion *)awsRegion {
    return awsRegion;
}
- (NSDate *)creationDate {
    return creationDate;
}
- (NSDate *)lastInventoryDate {
    return lastInventoryDate;
}
- (uint64_t)numberOfArchives {
    return numberOfArchives;
}
- (uint64_t)size {
    return size;
}
- (NSString *)vaultARN {
    return vaultARN;
}
- (NSString *)vaultName {
    return vaultName;
}
@end
