//
//  GoogleDriveTargetConnection.m
//  Arq
//
//  Created by Stefan Reitshamer on 7/18/14.
//  Copyright (c) 2014 Stefan Reitshamer. All rights reserved.
//

#import "GoogleDriveTargetConnection.h"
#import "GoogleDriveRemoteFS.h"
#import "BaseTargetConnection.h"
#import "S3ObjectMetadata.h"


@implementation GoogleDriveTargetConnection
- (id)initWithTarget:(Target *)theTarget {
    if (self = [super init]) {
        googleDriveRemoteFS = [[GoogleDriveRemoteFS alloc] initWithTarget:theTarget];
        base = [[BaseTargetConnection alloc] initWithTarget:theTarget remoteFS:googleDriveRemoteFS];
    }
    return self;
}
- (void)dealloc {
    [googleDriveRemoteFS release];
    [base release];
    [super dealloc];
}


#pragma mark TargetConnection
- (NSArray *)computerUUIDsWithDelegate:(id<TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    return [base computerUUIDsWithDelegate:theDelegate error:error];
}
- (NSArray *)bucketUUIDsForComputerUUID:(NSString *)theComputerUUID deleted:(BOOL)deleted delegate:(id<TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    return [base bucketUUIDsForComputerUUID:theComputerUUID deleted:deleted delegate:theDelegate error:error];
}
- (NSData *)bucketPlistDataForComputerUUID:(NSString *)theComputerUUID bucketUUID:(NSString *)theBucketUUID deleted:(BOOL)deleted delegate:(id<TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    return [base bucketPlistDataForComputerUUID:theComputerUUID bucketUUID:theBucketUUID deleted:deleted delegate:theDelegate error:error];
}
- (BOOL)saveBucketPlistData:(NSData *)theData forComputerUUID:(NSString *)theComputerUUID bucketUUID:(NSString *)theBucketUUID deleted:(BOOL)deleted delegate:(id<TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    return [base saveBucketPlistData:theData forComputerUUID:theComputerUUID bucketUUID:theBucketUUID deleted:deleted delegate:theDelegate error:error];
}
- (BOOL)deleteBucketPlistDataForComputerUUID:(NSString *)theComputerUUID bucketUUID:(NSString *)theBucketUUID deleted:(BOOL)deleted delegate:(id<TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    return [base deleteBucketPlistDataForComputerUUID:theComputerUUID bucketUUID:theBucketUUID deleted:deleted delegate:theDelegate error:error];
}
- (NSData *)computerInfoForComputerUUID:(NSString *)theComputerUUID delegate:(id<TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    return [base computerInfoForComputerUUID:theComputerUUID delegate:theDelegate error:error];
}
- (BOOL)saveComputerInfo:(NSData *)theData forComputerUUID:(NSString *)theComputerUUID delegate:(id<TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    return [base saveComputerInfo:theData forComputerUUID:theComputerUUID delegate:theDelegate error:error];
}
- (NSDictionary *)objectsBySHA1ForTargetEndpoint:(NSURL *)theEndpoint isGlacier:(BOOL)theIsGlacier computerUUID:(NSString *)theComputerUUID delegate:(id<TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    NSString *prefix = [NSString stringWithFormat:@"%@/%@/objects/", [theEndpoint path], theComputerUUID];
    
    NSArray *objects = [base objectsWithPrefix:prefix delegate:theDelegate error:error];
    if (objects == nil) {
        return nil;
    }
    NSMutableDictionary *ret = [NSMutableDictionary dictionary];
    for (S3ObjectMetadata *md in objects) {
        [ret setObject:md forKey:[[md path] lastPathComponent]];
    }
    return ret;
}
- (NSArray *)pathsWithPrefix:(NSString *)thePrefix delegate:(id<TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    return [base pathsWithPrefix:thePrefix delegate:theDelegate error:error];
}
- (BOOL)deleteObjectsForComputerUUID:(NSString *)theComputerUUID delegate:(id<TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    return [base deleteObjectsForComputerUUID:theComputerUUID delegate:theDelegate error:error];
}
- (BOOL)deletePaths:(NSArray *)thePaths delegate:(id<TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    return [base deletePaths:thePaths delegate:theDelegate error:error];
}
- (NSNumber *)fileExistsAtPath:(NSString *)thePath dataSize:(unsigned long long *)theDataSize delegate:(id<TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    return [base fileExistsAtPath:thePath dataSize:theDataSize delegate:theDelegate error:error];
}
- (NSData *)contentsOfFileAtPath:(NSString *)thePath delegate:(id<TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    return [base contentsOfFileAtPath:thePath delegate:theDelegate error:error];
}
- (BOOL)writeData:(NSData *)theData toFileAtPath:(NSString *)thePath dataTransferDelegate:(id <DataTransferDelegate>)theDataTransferDelegate targetConnectionDelegate:(id<TargetConnectionDelegate>)theTargetConnectionDelegate error:(NSError **)error {
    return [base writeData:theData toFileAtPath:thePath dataTransferDelegate:theDataTransferDelegate targetConnectionDelegate:theTargetConnectionDelegate error:error];
}
- (BOOL)removeItemAtPath:(NSString *)thePath delegate:(id<TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    return [base removeItemAtPath:thePath delegate:theDelegate error:error];
}
- (NSNumber *)sizeOfItemAtPath:(NSString *)thePath delegate:(id<TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    return [base sizeOfItemAtPath:thePath delegate:theDelegate error:error];
}
- (NSNumber *)isObjectRestoredAtPath:(NSString *)thePath delegate:(id<TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    return [base isObjectRestoredAtPath:thePath delegate:theDelegate error:error];
}
- (BOOL)restoreObjectAtPath:(NSString *)thePath forDays:(NSUInteger)theDays alreadyRestoredOrRestoring:(BOOL *)alreadyRestoredOrRestoring delegate:(id<TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    return [base restoreObjectAtPath:thePath forDays:theDays alreadyRestoredOrRestoring:alreadyRestoredOrRestoring delegate:theDelegate error:error];
}
- (NSData *)saltDataForComputerUUID:(NSString *)theComputerUUID delegate:(id<TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    return [base saltDataForComputerUUID:theComputerUUID delegate:theDelegate error:error];
}
- (BOOL)setSaltData:(NSData *)theData forComputerUUID:(NSString *)theComputerUUID delegate:(id<TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    return [base setSaltData:theData forComputerUUID:theComputerUUID delegate:theDelegate error:error];
}

@end
