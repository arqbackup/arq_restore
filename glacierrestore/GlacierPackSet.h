//
//  GlacierPackSet.h
//
//  Created by Stefan Reitshamer on 11/3/12.
//  Copyright (c) 2012 Stefan Reitshamer. All rights reserved.
//

@class S3Service;
@class GlacierService;
@class PackIndexEntry;
@class GlacierPackIndex;
@class Target;
@protocol TargetConnectionDelegate;


@interface GlacierPackSet : NSObject {
    Target *target;
    S3Service *s3;
    GlacierService *glacier;
    NSString *s3BucketName;
    NSString *computerUUID;
    NSString *packSetName;
    uid_t targetUID;
    uid_t targetGID;
    BOOL loadedPIEs;
    
    NSMutableDictionary *glacierPackIndexesByPackSHA1;
    NSMutableDictionary *packIndexEntriesByObjectSHA1;
}
+ (NSString *)errorDomain;
+ (unsigned long long)maxPackFileSizeMB;
+ (unsigned long long)maxPackItemSizeBytes;

- (id)initWithTarget:(Target *)theTarget
                  s3:(S3Service *)theS3
             glacier:(GlacierService *)theGlacier
           vaultName:(NSString *)theVaultName
        s3BucketName:(NSString *)theS3BucketName
        computerUUID:(NSString *)theComputerUUID
         packSetName:(NSString *)thePackSetName
           targetUID:(uid_t)theTargetUID
           targetGID:(uid_t)theTargetGID;

- (BOOL)containsBlob:(BOOL *)contains forSHA1:(NSString *)sha1 dataSize:(unsigned long long *)dataSize targetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD error:(NSError **)error;
- (GlacierPackIndex *)glacierPackIndexForObjectSHA1:(NSString *)theObjectSHA1 targetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD error:(NSError **)error;
- (PackIndexEntry *)packIndexEntryForObjectSHA1:(NSString *)theSHA1 targetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD error:(NSError **)error;
@end
