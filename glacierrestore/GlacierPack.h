//
//  GlacierPack.h
//
//  Created by Stefan Reitshamer on 11/3/12.
//  Copyright (c) 2012 Stefan Reitshamer. All rights reserved.
//

@class Target;


@interface GlacierPack : NSObject {
    NSString *s3BucketName;
    NSString *computerUUID;
    NSString *bucketUUID;
    NSString *packSetName;
    NSString *packSHA1;
    NSString *archiveId;
    NSString *localPath;
    unsigned long long packSize;
    uid_t uid;
    gid_t gid;
}
- (id)initWithTarget:(Target *)theTarget
        s3BucketName:(NSString *)theS3BucketName
        computerUUID:(NSString *)theComputerUUID
          bucketUUID:(NSString *)theBucketUUID
            packSHA1:(NSString *)thePackSHA1
           archiveId:(NSString *)theArchiveId
            packSize:(unsigned long long)thePackSize
           targetUID:(uid_t)theTargetUID
           targetGID:(gid_t)theTargetGID;

- (NSString *)packSHA1;
- (NSString *)archiveId;
- (unsigned long long)packSize;
- (BOOL)cachePackDataToDisk:(NSData *)thePackData error:(NSError **)error;
- (NSData *)cachedDataForObjectAtOffset:(unsigned long long)offset error:(NSError **)error;
@end
