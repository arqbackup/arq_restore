//
//  DiskPackIndex.h
//  Arq
//
//  Created by Stefan Reitshamer on 12/30/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//


@class PackIndexEntry;
@class S3Service;

@interface DiskPackIndex : NSObject {
    S3Service *s3;
    NSString *s3BucketName;
    NSString *computerUUID;
    NSString *packSetName;
    NSString *packSHA1;
    NSString *s3Path;
    NSString *localPath;
    uid_t targetUID;
    gid_t targetGID;
}
+ (NSString *)s3PathWithS3BucketName:(NSString *)theS3BucketName computerUUID:(NSString *)theComputerUUID packSetName:(NSString *)thePackSetName packSHA1:(NSString *)thePackSHA1;
+ (NSString *)localPathWithS3BucketName:theS3BucketName computerUUID:(NSString *)theComputerUUID packSetName:(NSString *)thePackSetName packSHA1:(NSString *)thePackSHA1;
+ (NSArray *)diskPackIndexesForS3Service:(S3Service *)theS3
                            s3BucketName:theS3BucketName 
                            computerUUID:(NSString *)theComputerUUID 
                             packSetName:(NSString *)thePackSetName 
                               targetUID:(uid_t)theTargetUID 
                               targetGID:(gid_t)theTargetGID
                                   error:(NSError **)error;

- (id)initWithS3Service:(S3Service *)theS3 
           s3BucketName:(NSString *)theS3BucketName 
           computerUUID:(NSString *)theComputerUUID 
            packSetName:(NSString *)thePackSetName 
               packSHA1:(NSString *)thePackSHA1
              targetUID:(uid_t)theTargetUID 
              targetGID:(gid_t)theTargetGID;
- (BOOL)makeLocal:(NSError **)error;
- (NSArray *)allPackIndexEntries:(NSError **)error;
- (PackIndexEntry *)entryForSHA1:(NSString *)sha1 error:(NSError **)error;
- (NSString *)packSetName;
- (NSString *)packSHA1;
@end
