/*
 Copyright (c) 2009-2017, Haystack Software LLC https://www.arqbackup.com
 
 All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 
 * Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in the
 documentation and/or other materials provided with the distribution.
 
 * Neither the names of PhotoMinds LLC or Haystack Software, nor the names of
 their contributors may be used to endorse or promote products derived from
 this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
 TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */




#import "TargetConnection.h"
#import "StorageType.h"
@class Target;
@class BlobKey;
@class PackId;
@class PackIndexEntry;
@protocol DataTransferDelegate;
@class ReflogEntry;
#import "DeleteDelegate.h"


@interface Fark : NSObject {
    Target *target;
    TargetConnection *targetConnection;
    NSString *computerUUID;
    id <TargetConnectionDelegate> targetConnectionDelegate;
    
    NSMutableSet *packIdsAlreadyPostedForRestore;
    NSMutableSet *downloadablePackIds;
}
- (id)initWithTarget:(Target *)theTarget
        computerUUID:(NSString *)theComputerUUID
targetConnectionDelegate:(id <TargetConnectionDelegate>)theTargetConnectionDelegate
               error:(NSError **)error;

- (NSString *)errorDomain;

- (NSString *)targetUUID;
- (NSString *)computerUUID;

- (BlobKey *)headBlobKeyForBucketUUID:(NSString *)theBucketUUID error:(NSError **)error;
- (BOOL)setHeadBlobKey:(BlobKey *)theHeadBlobKey forBucketUUID:(NSString *)theBucketUUID error:(NSError **)error;
- (BOOL)deleteHeadBlobKeyForBucketUUID:(NSString *)theBucketUUID error:(NSError **)error;

- (NSArray *)reflogEntryIdsForBucketUUID:(NSString *)theBucketUUID error:(NSError **)error;
- (ReflogEntry *)reflogEntryWithId:(NSString *)theReflogEntryId bucketUUID:(NSString *)theBucketUUID error:(NSError **)error;

- (BOOL)clearBucketDataItemsDBCacheForBucketUUID:(NSString *)theBucketUUID error:(NSError **)error;
- (BOOL)clearItemsDBCache:(NSError **)error;

- (NSNumber *)containsObjectInCacheForSHA1:(NSString *)theSHA1 storageType:(StorageType)theStorageType error:(NSError **)error;
- (NSNumber *)sizeOfObjectInCacheForSHA1:(NSString *)theSHA1 storageType:(StorageType)theStorageType error:(NSError **)error;

- (NSNumber *)isObjectDownloadableForSHA1:(NSString *)theSHA1 storageType:(StorageType)theStorageType error:(NSError **)error;
- (BOOL)restoreObjectForSHA1:(NSString *)theSHA1 forDays:(NSUInteger)theDays tier:(int)theGlacierRetrievalTier storageType:(StorageType)theStorageType alreadyRestoredOrRestoring:(BOOL *)alreadyRestoredOrRestoring error:(NSError **)error;
- (NSData *)dataForSHA1:(NSString *)theSHA1 storageType:(StorageType)theStorageType error:(NSError **)error;
- (NSData *)dataForSHA1:(NSString *)theSHA1 storageType:(StorageType)theStorageType refreshCache:(BOOL)refreshCache error:(NSError **)error;
- (NSData *)dataWithRange:(NSRange)theRange forSHA1:(NSString *)theSHA1 storageType:(StorageType)theStorageType error:(NSError **)error;

- (NSString *)checksumOfObjectWithSHA1:(NSString *)theSHA1 storageType:(StorageType)theStorageType error:(NSError **)error;

- (BOOL)putData:(NSData *)theData forSHA1:(NSString *)theSHA1 storageType:(StorageType)theStorageType error:(NSError **)error;
- (BOOL)putData:(NSData *)theData forSHA1:(NSString *)theSHA1 storageType:(StorageType)theStorageType dataTransferDelegate:(id <DataTransferDelegate>)theDelegate error:(NSError **)error;

- (NSSet *)packIdsForPackSet:(NSString *)packSetName storageType:(StorageType)theStorageType error:(NSError **)error;
- (BOOL)clearCachedPackIdsForPackSet:(NSString *)thePackSetName storageType:(StorageType)theStorageType error:(NSError **)error;

// Indexes are always in S3; no StorageType needed.
- (NSData *)indexDataForPackId:(PackId *)thePackId error:(NSError **)error;
//- (BOOL)isIndexCachedForPackId:(PackId *)thePackId;
//- (BOOL)cacheIndexDataForPackId:(PackId *)thePackId error:(NSError **)error;
- (BOOL)putIndexData:(NSData *)theData forPackId:(PackId *)thePackId error:(NSError **)error;
- (BOOL)deleteIndex:(PackId *)thePackId error:(NSError **)error;

//- (void)cacheIndexesForPackIds:(NSSet *)thePackIds;

- (NSNumber *)isPackDownloadableWithId:(PackId *)packId storageType:(StorageType)theStorageType error:(NSError **)error;
- (BOOL)restorePackWithId:(PackId *)packId forDays:(NSUInteger)theDays tier:(int)theGlacierRetrievalTier storageType:(StorageType)theStorageType alreadyRestoredOrRestoring:(BOOL *)alreadyRestoredOrRestoring error:(NSError **)error;

- (NSData *)packDataForPackId:(PackId *)packId storageType:(StorageType)theStorageType error:(NSError **)error;
- (NSData *)dataForPackIndexEntry:(PackIndexEntry *)thePIE storageType:(StorageType)theStorageType error:(NSError **)error;

- (BOOL)putPackData:(NSData *)theData forPackId:(PackId *)thePackId storageType:(StorageType)theStorageType saveToCache:(BOOL)saveToCache error:(NSError **)error;

- (BOOL)deletePack:(PackId *)thePackId storageType:(StorageType)theStorageType error:(NSError **)error;

- (BOOL)putReflogItem:(NSData *)itemData forBucketUUID:(NSString *)theBucketUUID error:(NSError **)error;

- (BOOL)deleteObjectForSHA1:(NSString *)theSHA1 storageType:(StorageType)theStorageType error:(NSError **)error;

@end
