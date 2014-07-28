//
//  GlacierService.h
//  Arq
//
//  Created by Stefan Reitshamer on 9/7/12.
//
//

@class Vault;
@class GlacierAuthorizationProvider;
@class AWSRegion;
@protocol DataTransferDelegate;


enum {
    GLACIER_ERROR_UNEXPECTED_RESPONSE = -51001,
    GLACIER_ERROR_AMAZON_ERROR = -51002,
    GLACIER_INVALID_PARAMETERS = -51003
};


@interface GlacierService : NSObject {
    GlacierAuthorizationProvider *gap;
    AWSRegion *awsRegion;
    BOOL useSSL;
    BOOL retryOnTransientError;
}
+ (NSString *)errorDomain;

- (id)initWithGlacierAuthorizationProvider:(GlacierAuthorizationProvider *)theGAP awsRegion:(AWSRegion *)theAWSRegion useSSL:(BOOL)theUseSSL retryOnTransientError:(BOOL)retry;

- (NSArray *)vaults:(NSError **)error;
- (Vault *)vaultWithName:(NSString *)theVaultName error:(NSError **)error;
- (BOOL)createVaultWithName:(NSString *)theName error:(NSError **)error;
- (BOOL)deleteVaultWithName:(NSString *)theName error:(NSError **)error;
- (NSString *)uploadArchive:(NSData *)data toVaultName:(NSString *)theVaultName error:(NSError **)error;
- (NSString *)uploadArchive:(NSData *)data toVaultName:(NSString *)theVaultName dataTransferDelegate:(id <DataTransferDelegate>)theDelegate error:(NSError **)error;
- (BOOL)deleteArchive:(NSString *)theArchiveId inVault:(NSString *)theVaultName error:(NSError **)error;
- (NSString *)initiateRetrievalJobForVaultName:(NSString *)theVaultName archiveId:(NSString *)theArchiveId snsTopicArn:(NSString *)theSNSTopicArn error:(NSError **)error;
- (NSString *)initiateInventoryJobForVaultName:(NSString *)theVaultName snsTopicArn:(NSString *)theSNSTopicArn error:(NSError **)error;
- (NSArray *)jobsForVaultName:(NSString *)theVaultName error:(NSError **)error;
- (NSData *)dataForVaultName:(NSString *)theVaultName jobId:(NSString *)theJobId retries:(NSUInteger)theRetries error:(NSError **)error;
@end
