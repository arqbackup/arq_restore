//
//  BaseTargetConnection.h
//  Arq
//
//  Created by Stefan Reitshamer on 4/12/14.
//  Copyright (c) 2014 Stefan Reitshamer. All rights reserved.
//

@class Target;
@protocol RemoteFS;
@protocol TargetConnectionDelegate;


@interface BaseTargetConnection : NSObject {
    Target *target;
    id <RemoteFS> remoteFS;
    NSString *pathPrefix;
}

- (id)initWithTarget:(Target *)theTarget remoteFS:(id <RemoteFS>)theRemoteFS;

- (NSArray *)computerUUIDsWithDelegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error;
- (NSArray *)bucketUUIDsForComputerUUID:(NSString *)theComputerUUID deleted:(BOOL)deleted delegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error;

- (NSData *)bucketPlistDataForComputerUUID:(NSString *)theComputerUUID bucketUUID:(NSString *)theBucketUUID deleted:(BOOL)deleted delegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error;
- (BOOL)saveBucketPlistData:(NSData *)theData forComputerUUID:(NSString *)theComputerUUID bucketUUID:(NSString *)theBucketUUID deleted:(BOOL)deleted delegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error;
- (BOOL)deleteBucketPlistDataForComputerUUID:(NSString *)theComputerUUID bucketUUID:(NSString *)theBucketUUID deleted:(BOOL)deleted delegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error;

- (NSData *)computerInfoForComputerUUID:(NSString *)theComputerUUID delegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error;
- (BOOL)saveComputerInfo:(NSData *)theData forComputerUUID:(NSString *)theComputerUUID delegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error;

- (NSArray *)objectsWithPrefix:(NSString *)thePrefix delegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error;
- (NSArray *)pathsWithPrefix:(NSString *)thePrefix delegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error;
- (BOOL)deleteObjectsForComputerUUID:(NSString *)theComputerUUID delegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error;
- (BOOL)deletePaths:(NSArray *)thePaths delegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error;

- (NSNumber *)fileExistsAtPath:(NSString *)thePath dataSize:(unsigned long long *)theDataSize delegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error;
- (NSData *)contentsOfFileAtPath:(NSString *)thePath delegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error;
- (BOOL)writeData:(NSData *)theData toFileAtPath:(NSString *)thePath dataTransferDelegate:(id <DataTransferDelegate>)theDataTransferDelegate targetConnectionDelegate:(id <TargetConnectionDelegate>)theTargetConnectionDelegate error:(NSError **)error;
- (BOOL)removeItemAtPath:(NSString *)thePath delegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error;
- (NSNumber *)sizeOfItemAtPath:(NSString *)thePath delegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error;
- (NSNumber *)isObjectRestoredAtPath:(NSString *)thePath delegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error;
- (BOOL)restoreObjectAtPath:(NSString *)thePath forDays:(NSUInteger)theDays alreadyRestoredOrRestoring:(BOOL *)alreadyRestoredOrRestoring delegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error;

- (NSData *)saltDataForComputerUUID:(NSString *)theComputerUUID delegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error;
- (BOOL)setSaltData:(NSData *)theData forComputerUUID:(NSString *)theComputerUUID delegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error;

@end
