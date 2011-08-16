//
//  DiskPack.h
//  Arq
//
//  Created by Stefan Reitshamer on 12/30/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
@class S3Service;
@class ServerBlob;

@interface DiskPack : NSObject {
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
+ (NSString *)localPathWithS3BucketName:(NSString *)theS3BucketName computerUUID:(NSString *)theComputerUUID packSetName:(NSString *)thePackSetName packSHA1:(NSString *)thePackSHA1;
- (id)initWithS3Service:(S3Service *)theS3 
           s3BucketName:(NSString *)theS3BucketName 
           computerUUID:(NSString *)theComputerUUID 
            packSetName:(NSString *)thePackSetName 
               packSHA1:(NSString *)thePackSHA1
              targetUID:(uid_t)theTargetUID 
              targetGID:(gid_t)theTargetGID;
- (BOOL)makeLocal:(NSError **)error;
- (BOOL)makeNotLocal:(NSError **)error;
- (ServerBlob *)newServerBlobForObjectAtOffset:(unsigned long long)offset error:(NSError **)error;
- (BOOL)fileLength:(unsigned long long *)length error:(NSError **)error;
- (BOOL)copyToPath:(NSString *)dest error:(NSError **)error;
- (NSArray *)sortedPackIndexEntries:(NSError **)error;
@end
