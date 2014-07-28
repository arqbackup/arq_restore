//
//  Fark.h
//  Arq
//
//  Created by Stefan Reitshamer on 12/31/13.
//  Copyright (c) 2013 Stefan Reitshamer. All rights reserved.
//

#import "StorageType.h"
@class BlobKey;
@class PackId;
@class PackIndexEntry;
@protocol DataTransferDelegate;

@protocol Fark <NSObject>

- (NSString *)errorDomain;

- (BlobKey *)headBlobKeyForBucketUUID:(NSString *)theBucketUUID error:(NSError **)error;
- (BOOL)setHeadBlobKey:(BlobKey *)theHeadBlobKey forBucketUUID:(NSString *)theBucketUUID error:(NSError **)error;
- (BOOL)deleteHeadBlobKeyForBucketUUID:(NSString *)theBucketUUID error:(NSError **)error;

- (NSNumber *)containsObjectForSHA1:(NSString *)theSHA1 storageType:(StorageType)theStorageType dataSize:(unsigned long long *)dataSize forceTargetCheck:(BOOL)forceTargetCheck error:(NSError **)error;

- (NSNumber *)isObjectDownloadableForSHA1:(NSString *)theSHA1 storageType:(StorageType)theStorageType error:(NSError **)error;
- (BOOL)restoreObjectForSHA1:(NSString *)theSHA1 forDays:(NSUInteger)theDays storageType:(StorageType)theStorageType alreadyRestoredOrRestoring:(BOOL *)alreadyRestoredOrRestoring error:(NSError **)error;
- (NSData *)dataForSHA1:(NSString *)theSHA1 storageType:(StorageType)theStorageType error:(NSError **)error;

- (BOOL)putData:(NSData *)theData forSHA1:(NSString *)theSHA1 storageType:(StorageType)theStorageType error:(NSError **)error;
- (BOOL)putData:(NSData *)theData forSHA1:(NSString *)theSHA1 storageType:(StorageType)theStorageType dataTransferDelegate:(id <DataTransferDelegate>)theDelegate error:(NSError **)error;

- (NSSet *)packIdsForPackSet:(NSString *)packSetName storageType:(StorageType)theStorageType error:(NSError **)error;

// Indexes are always in S3; no StorageType needed.
- (NSData *)indexDataForPackId:(PackId *)packId error:(NSError **)error;
- (BOOL)putIndexData:(NSData *)theData forPackId:(PackId *)thePackId error:(NSError **)error;
- (BOOL)deleteIndex:(PackId *)thePackId error:(NSError **)error;


- (NSNumber *)sizeOfPackWithId:(PackId *)packId storageType:(StorageType)theStorageType error:(NSError **)error;
- (NSNumber *)isPackDownloadableWithId:(PackId *)packId storageType:(StorageType)theStorageType error:(NSError **)error;
- (BOOL)restorePackWithId:(PackId *)packId forDays:(NSUInteger)theDays storageType:(StorageType)theStorageType alreadyRestoredOrRestoring:(BOOL *)alreadyRestoredOrRestoring error:(NSError **)error;

- (NSData *)packDataForPackId:(PackId *)packId storageType:(StorageType)theStorageType error:(NSError **)error;
- (NSData *)dataForPackIndexEntry:(PackIndexEntry *)thePIE storageType:(StorageType)theStorageType error:(NSError **)error;

- (BOOL)putPackData:(NSData *)theData forPackId:(PackId *)thePackId storageType:(StorageType)theStorageType saveToCache:(BOOL)saveToCache error:(NSError **)error;

- (BOOL)deletePack:(PackId *)thePackId storageType:(StorageType)theStorageType error:(NSError **)error;

- (BOOL)putReflogItem:(NSData *)itemData forBucketUUID:(NSString *)theBucketUUID error:(NSError **)error;

@end
