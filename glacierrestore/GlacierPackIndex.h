//
//  GlacierPackIndex.h
//
//  Created by Stefan Reitshamer on 11/3/12.
//  Copyright (c) 2012 Stefan Reitshamer. All rights reserved.
//

@class S3Service;
@class PackIndexEntry;
@class PackId;
@class Target;
@protocol TargetConnectionDelegate;


@interface GlacierPackIndex : NSObject {
    S3Service *s3;
    NSString *s3BucketName;
    NSString *computerUUID;
    PackId *packId;
    NSString *s3Path;
    NSString *localPath;
    uid_t targetUID;
    gid_t targetGID;
    NSMutableArray *pies;
    NSString *archiveId;
    unsigned long long packSize;
}
+ (NSString *)s3PathWithS3BucketName:(NSString *)theS3BucketName computerUUID:(NSString *)theComputerUUID packId:(PackId *)thePackId;
+ (NSString *)localPathWithTarget:(Target *)theTarget computerUUID:(NSString *)theComputerUUID packId:(PackId *)thePackId;
+ (NSArray *)glacierPackIndexesForTarget:(Target *)theTarget
                               s3Service:(S3Service *)theS3
                            s3BucketName:theS3BucketName
                            computerUUID:(NSString *)theComputerUUID
                             packSetName:(NSString *)thePackSetName
                targetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD
                               targetUID:(uid_t)theTargetUID
                               targetGID:(gid_t)theTargetGID
                                   error:(NSError **)error;

- (id)initWithTarget:(Target *)theTarget
           s3Service:(S3Service *)theS3
        s3BucketName:(NSString *)theS3BucketName
        computerUUID:(NSString *)theComputerUUID
              packId:(PackId *)thePackId
           targetUID:(uid_t)theTargetUID
           targetGID:(gid_t)theTargetGID;
- (BOOL)makeLocalWithTargetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD error:(NSError **)error;
- (NSArray *)allPackIndexEntriesWithTargetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD error:(NSError **)error;
- (PackIndexEntry *)entryForSHA1:(NSString *)sha1 error:(NSError **)error;
- (PackId *)packId;
- (NSString *)archiveId:(NSError **)error;
- (unsigned long long)packSize:(NSError **)error;
@end
