//
//  BlobKey.h
//
//  Created by Stefan Reitshamer on 6/27/11.
//  Copyright 2011 Haystack Software. All rights reserved.
//

#import "StorageType.h"
@class BufferedInputStream;


@interface BlobKey : NSObject <NSCopying> {
    StorageType storageType;
    NSString *archiveId;
    uint64_t archiveSize;
    NSDate *archiveUploadedDate;
    NSString *sha1;
    BOOL stretchEncryptionKey;
    BOOL compressed;
}
- (id)initWithSHA1:(NSString *)theSHA1 archiveId:(NSString *)theArchiveId archiveSize:(uint64_t)theArchiveSize archiveUploadedDate:(NSDate *)theArchiveUploadedDate compressed:(BOOL)isCompressed;
- (id)initWithSHA1:(NSString *)theSHA1 storageType:(StorageType)theStorageType stretchEncryptionKey:(BOOL)isStretchedKey compressed:(BOOL)isCompressed;
- (id)initWithStorageType:(StorageType)theStorageType archiveId:(NSString *)theArchiveId archiveSize:(uint64_t)theArchiveSize archiveUploadedDate:(NSDate *)theArchiveUploadedDate sha1:(NSString *)theSHA1 stretchEncryptionKey:(BOOL)isStretchedKey compressed:(BOOL)isCompressed;

- (StorageType)storageType;
- (NSString *)archiveId;
- (uint64_t)archiveSize;
- (NSDate *)archiveUploadedDate;
- (NSString *)sha1;
- (BOOL)stretchEncryptionKey;
- (BOOL)compressed;
- (BOOL)isEqualToBlobKey:(BlobKey *)other;
@end
