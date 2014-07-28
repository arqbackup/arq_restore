//
//  BackupVolume.h
//
//  Created by Stefan Reitshamer on 3/25/11.
//  Copyright 2011 Haystack Software. All rights reserved.
//


#import "StorageType.h"
@class AWSRegion;
@class DictNode;
@class BucketExcludeSet;
@class BackupParamSet;
@class Target;
@class BufferedInputStream;
@class BufferedOutputStream;
@protocol TargetConnectionDelegate;


enum {
    BucketPathMixedState = -1,
    BucketPathOffState   =  0,
    BucketPathOnState    =  1
};
typedef NSInteger BucketPathState;

@interface Bucket : NSObject <NSCopying> {
    Target *target;
    NSString *bucketUUID;
    NSString *bucketName;
    NSString *computerUUID;
    NSString *localPath;
    NSString *localMountPoint;
    StorageType storageType;
    NSMutableArray *ignoredRelativePaths;
    BucketExcludeSet *excludeSet;
    NSMutableArray *stringArrayPairs;
    NSString *vaultName;
    NSDate *vaultCreatedDate;
    NSDate *plistDeletedDate;
}

+ (NSArray *)bucketsWithTarget:(Target *)theTarget
                  computerUUID:(NSString *)theComputerUUID
            encryptionPassword:(NSString *)theEncryptionPassword
      targetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD
                         error:(NSError **)error;

+ (NSArray *)bucketUUIDsWithTarget:(Target *)theTarget
                      computerUUID:(NSString *)theComputerUUID
                encryptionPassword:(NSString *)theEncryptionPassword
          targetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD
                             error:(NSError **)error;

+ (NSArray *)deletedBucketsWithTarget:(Target *)theTarget
                         computerUUID:(NSString *)theComputerUUID
                   encryptionPassword:(NSString *)theEncryptionPassword
             targetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD
                                error:(NSError **)error;

+ (NSString *)errorDomain;

- (id)initWithTarget:(Target *)theTarget
          bucketUUID:(NSString *)theBucketUUID
          bucketName:(NSString *)theBucketName
        computerUUID:(NSString *)theComputerUUID
           localPath:(NSString *)theLocalPath
     localMountPoint:(NSString *)theLocalMountPoint
         storageType:(int)theStorageType;
- (id)initWithBufferedInputStream:(BufferedInputStream *)theBIS error:(NSError **)error;


- (Target *)target;
- (NSString *)computerUUID;
- (NSString *)bucketUUID;
- (NSString *)bucketName;
- (NSString *)localPath;
- (StorageType)storageType;
- (NSString *)localMountPoint;
- (BucketExcludeSet *)bucketExcludeSet;
- (NSString *)vaultName;
- (NSDate *)vaultCreatedDate;
- (NSDate *)plistDeletedDate;
- (BucketPathState)stateForPath:(NSString *)thePath ignoreExcludes:(BOOL)ignoreExcludes;
- (void)setIgnoredRelativePaths:(NSSet *)theSet;
- (NSSet *)ignoredRelativePaths;
- (void)enteredPath:(NSString *)thePath;
- (void)leftPath:(NSString *)thePath;
- (NSData *)toXMLData;
@end
