//
//  BlobKey.m
//
//  Created by Stefan Reitshamer on 6/27/11.
//  Copyright 2011 Haystack Software. All rights reserved.
//

#import "BlobKey.h"
#import "BufferedInputStream.h"
#import "StringIO.h"
#import "BooleanIO.h"
#import "IntegerIO.h"
#import "NSObject_extra.h"


@implementation BlobKey
- (id)initWithSHA1:(NSString *)theSHA1 archiveId:(NSString *)theArchiveId archiveSize:(uint64_t)theArchiveSize archiveUploadedDate:(NSDate *)theArchiveUploadedDate compressed:(BOOL)isCompressed {
    if (self = [super init]) {
        storageType = StorageTypeGlacier;
        sha1 = [theSHA1 retain];
        archiveId = [theArchiveId retain];
        archiveSize = theArchiveSize;
        archiveUploadedDate = [theArchiveUploadedDate retain];
        compressed = isCompressed;
    }
    return self;
}
- (id)initWithSHA1:(NSString *)theSHA1 storageType:(StorageType)theStorageType stretchEncryptionKey:(BOOL)isStretchedKey compressed:(BOOL)isCompressed {
    if (self = [super init]) {
        storageType = theStorageType;
        sha1 = [theSHA1 retain];
        stretchEncryptionKey = isStretchedKey;
        compressed = isCompressed;
    }
    return self;
}
- (id)initWithStorageType:(StorageType)theStorageType archiveId:(NSString *)theArchiveId archiveSize:(uint64_t)theArchiveSize archiveUploadedDate:(NSDate *)theArchiveUploadedDate sha1:(NSString *)theSHA1 stretchEncryptionKey:(BOOL)isStretchedKey compressed:(BOOL)isCompressed {
    if (self = [super init]) {
        storageType = theStorageType;
        archiveId = [theArchiveId retain];
        archiveSize = theArchiveSize;
        archiveUploadedDate = [theArchiveUploadedDate retain];
        sha1 = [theSHA1 retain];
        stretchEncryptionKey = isStretchedKey;
        compressed = isCompressed;
    }
    return self;
}
- (void)dealloc {
    [archiveId release];
    [archiveUploadedDate release];
    [sha1 release];
    [super dealloc];
}

- (StorageType)storageType {
    return storageType;
}
- (NSString *)archiveId {
    return archiveId;
}
- (uint64_t)archiveSize {
    return archiveSize;
}
- (NSDate *)archiveUploadedDate {
    return archiveUploadedDate;
}
- (NSString *)sha1 {
    return sha1;
}
- (BOOL)stretchEncryptionKey {
    return stretchEncryptionKey;
}
- (BOOL)compressed {
    return compressed;
}
- (BOOL)isEqualToBlobKey:(BlobKey *)other {
    if (![[other sha1] isEqualToString:sha1]) {
        return NO;
    }
    if (stretchEncryptionKey != [other stretchEncryptionKey]) {
        return NO;
    }
    return YES;
}


#pragma mark NSCopying
- (id)copyWithZone:(NSZone *)zone {
    return [[BlobKey alloc] initWithStorageType:storageType archiveId:archiveId archiveSize:archiveSize archiveUploadedDate:archiveUploadedDate sha1:sha1 stretchEncryptionKey:stretchEncryptionKey compressed:compressed];
}


#pragma mark NSObject
- (NSString *)description {
    if (storageType == StorageTypeS3) {
        return [NSString stringWithFormat:@"<BlobKey sha1=%@,stretchedkey=%@,compressed=%@>", sha1, (stretchEncryptionKey ? @"YES" : @"NO"), (compressed ? @"YES" : @"NO")];
    }
    return [NSString stringWithFormat:@"<BlobKey archiveId=%@,archiveUploadedDate=%@,stretchedkey=%@,compressed=%@>", archiveId, archiveUploadedDate, (stretchEncryptionKey ? @"YES" : @"NO"), (compressed ? @"YES" : @"NO")];
}
- (BOOL)isEqual:(id)anObject {
    if (![anObject isKindOfClass:[BlobKey class]]) {
        return NO;
    }
    BlobKey *other = (BlobKey *)anObject;
    
    return [NSObject equalObjects:sha1 and:[other sha1]]
    && stretchEncryptionKey == [other stretchEncryptionKey]
    && storageType == [other storageType]
    && [NSObject equalObjects:archiveId and:[other archiveId]]
    && archiveSize == [other archiveSize]
    && [NSObject equalObjects:archiveUploadedDate and:[other archiveUploadedDate]]
    && compressed == [other compressed];
}
- (NSUInteger)hash {
    return [sha1 hash] + (stretchEncryptionKey ? 1 : 0) + (compressed ? 1 : 0);
}
@end
