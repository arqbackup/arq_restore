//
//  PackSet.h
//  Arq
//
//  Created by Stefan Reitshamer on 12/30/13.
//  Copyright (c) 2013 Stefan Reitshamer. All rights reserved.
//

#import "StorageType.h"
@protocol Fark;
@class PackBuilder;
@class PackId;


@interface PackSet : NSObject {
    id <Fark> fark;
    StorageType storageType;
    NSString *packSetName;
    BOOL savePacksToCache;
    uid_t targetUID;
    gid_t targetGID;
    BOOL loadExistingMutablePackFiles;
    NSMutableDictionary *packIndexEntriesByObjectSHA1;
}


+ (unsigned long long)maxPackFileSizeMB;
+ (unsigned long long)maxPackItemSizeBytes;

- (id)initWithFark:(id <Fark>)theFark
       storageType:(StorageType)theStorageType
       packSetName:(NSString *)thePackSetName
  savePacksToCache:(BOOL)theSavePacksToCache
         targetUID:(uid_t)theTargetUID
         targetGID:(gid_t)theTargetGID
loadExistingMutablePackFiles:(BOOL)theLoadExistingMutablePackFiles;

- (NSString *)errorDomain;

- (NSString *)packSetName;
- (NSNumber *)containsBlobForSHA1:(NSString *)sha1 dataSize:(unsigned long long *)dataSize error:(NSError **)error;
- (PackId *)packIdForSHA1:(NSString *)theSHA1 error:(NSError **)error;
- (NSData *)dataForSHA1:(NSString *)sha1 withRetry:(BOOL)retry error:(NSError **)error;
- (BOOL)restorePackForBlobWithSHA1:(NSString *)theSHA1 forDays:(NSUInteger)theDays alreadyRestoredOrRestoring:(BOOL *)alreadyRestoredOrRestoring error:(NSError **)error;
- (NSNumber *)isObjectDownloadableForSHA1:(NSString *)theSHA1 error:(NSError **)error;
@end
