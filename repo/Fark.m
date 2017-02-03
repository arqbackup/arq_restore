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



#import "Fark.h"
#import "S3AuthorizationProvider.h"
#import "S3Service.h"
#import "Target.h"
#import "BlobKey.h"
#import "RegexKitLite.h"
#import "PackId.h"
#import "NSFileManager_extra.h"
#import "PackIndexEntry.h"
#import "DataInputStream.h"
#import "BufferedInputStream.h"
#import "StringIO.h"
#import "IntegerIO.h"
#import "FDInputStream.h"
#import "Streams.h"
#import "UserLibrary_Arq.h"
#import "AWSRegion.h"
#import "DictNode.h"
#import "ReflogEntry.h"
#import "CacheOwnership.h"
#import "Item.h"


@implementation Fark
- (id)initWithTarget:(Target *)theTarget
        computerUUID:(NSString *)theComputerUUID
targetConnectionDelegate:(id <TargetConnectionDelegate>)theTargetConnectionDelegate
               error:(NSError **)error {
    if (self = [super init]) {
        target = [theTarget retain];
        targetConnection = [target newConnection:error];
        if (targetConnection == nil) {
            [self release];
            return nil;
        }
        computerUUID = [theComputerUUID retain];
        targetConnectionDelegate = theTargetConnectionDelegate;
        packIdsAlreadyPostedForRestore = [[NSMutableSet alloc] init];
        downloadablePackIds = [[NSMutableSet alloc] init];
    }
    return self;
}
- (void)dealloc {
    [target release];
    [targetConnection release];
    [computerUUID release];
    [packIdsAlreadyPostedForRestore release];
    [downloadablePackIds release];
    [super dealloc];
}


#pragma mark Fark
- (NSString *)errorDomain {
    return @"FarkErrorDomain";
}

- (NSString *)targetUUID {
    return [target targetUUID];
}
- (NSString *)computerUUID {
    return computerUUID;
}

- (BlobKey *)headBlobKeyForBucketUUID:(NSString *)theBucketUUID error:(NSError **)error {
    NSError *myError = nil;
    NSData *data = [targetConnection contentsOfFileAtPath:[self masterPathForBucketUUID:theBucketUUID] delegate:targetConnectionDelegate error:&myError];
    if (data == nil) {
        SETERRORFROMMYERROR;
        if ([myError code] == ERROR_NOT_FOUND) {
            SETNSERROR([self errorDomain], ERROR_NOT_FOUND, @"head blob key not found for bucket %@", theBucketUUID);
        }
        return nil;
    }
    
    NSString *sha1 = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
    BOOL stretch = NO;
    if ([sha1 length] > 40) {
        stretch = [sha1 characterAtIndex:40] == 'Y';
        sha1 = [sha1 substringToIndex:40];
    }
    return [[[BlobKey alloc] initWithSHA1:sha1 storageType:StorageTypeS3 stretchEncryptionKey:stretch compressionType:BlobKeyCompressionNone error:error] autorelease];
}
- (BOOL)setHeadBlobKey:(BlobKey *)theHeadBlobKey forBucketUUID:(NSString *)theBucketUUID error:(NSError **)error {
    NSMutableString *str = [NSMutableString stringWithString:[theHeadBlobKey sha1]];
    if ([theHeadBlobKey stretchEncryptionKey]) {
        [str appendString:@"Y"];
    }
    NSData *data = [str dataUsingEncoding:NSUTF8StringEncoding];
    HSLogInfo(@"writing head blob key %@ for bucket %@", [theHeadBlobKey sha1], theBucketUUID);
    return [targetConnection writeData:data toFileAtPath:[self masterPathForBucketUUID:theBucketUUID] dataTransferDelegate:nil targetConnectionDelegate:targetConnectionDelegate error:error];
}
- (BOOL)deleteHeadBlobKeyForBucketUUID:(NSString *)theBucketUUID error:(NSError **)error {
    return [targetConnection removeItemAtPath:[self masterPathForBucketUUID:theBucketUUID] delegate:targetConnectionDelegate error:error];
}
- (NSArray *)reflogEntryIdsForBucketUUID:(NSString *)theBucketUUID error:(NSError **)error {
    NSString *reflogDir = [NSString stringWithFormat:@"%@/%@/bucketdata/%@/refs/logs/master", [self pathPrefix], computerUUID, theBucketUUID];

    NSDictionary *itemsByName = [targetConnection itemsByNameAtPath:reflogDir targetConnectionDelegate:targetConnectionDelegate error:error];
    if (itemsByName == nil) {
        return nil;
    }
    
    NSMutableArray *ret = [NSMutableArray array];
    for (Item *item in [itemsByName allValues]) {
        [ret addObject:item.name];
    }
    return ret;
}
- (ReflogEntry *)reflogEntryWithId:(NSString *)theReflogEntryId bucketUUID:(NSString *)theBucketUUID error:(NSError **)error {
    NSString *thePath = [NSString stringWithFormat:@"%@/%@/bucketdata/%@/refs/logs/master/%@", [self pathPrefix], computerUUID, theBucketUUID, theReflogEntryId];
    NSData *reflogEntryData = [targetConnection contentsOfFileAtPath:thePath delegate:targetConnectionDelegate error:error];
    if (reflogEntryData == nil) {
        return nil;
    }
    DictNode *plist = [DictNode dictNodeWithXMLData:reflogEntryData error:error];
    if (plist == nil) {
        return nil;
    }
    ReflogEntry *entry = [[[ReflogEntry alloc] initWithId:theReflogEntryId plist:plist error:error] autorelease];
    return entry;
}
- (BOOL)clearBucketDataItemsDBCacheForBucketUUID:(NSString *)theBucketUUID error:(NSError **)error {
    NSString *thePath = [NSString stringWithFormat:@"%@/%@/bucketdata/%@", [self pathPrefix], computerUUID, theBucketUUID];
    return [targetConnection clearCachedItemsForDirectory:thePath error:error];
}
- (BOOL)clearItemsDBCache:(NSError **)error {
    NSString *thePath = [NSString stringWithFormat:@"%@/%@", [self pathPrefix], computerUUID];
    return [targetConnection clearCachedItemsForDirectory:thePath error:error];
}

- (NSNumber *)containsObjectInCacheForSHA1:(NSString *)theSHA1 storageType:(StorageType)theStorageType error:(NSError **)error {
    return [self containsObjectInCacheForSHA1:theSHA1 storageType:theStorageType dataSize:NULL error:error];
}
- (NSNumber *)sizeOfObjectInCacheForSHA1:(NSString *)theSHA1 storageType:(StorageType)theStorageType error:(NSError **)error {
    unsigned long long size = 0;
    if (![self containsObjectInCacheForSHA1:theSHA1 storageType:theStorageType dataSize:&size error:error]) {
        return nil;
    }
    return [NSNumber numberWithUnsignedLongLong:size];
}
- (NSNumber *)containsObjectInCacheForSHA1:(NSString *)theSHA1 storageType:(StorageType)theStorageType dataSize:(unsigned long long *)dataSize error:(NSError **)error {
    if (theStorageType == StorageTypeGlacier) {
        // We assume that Glacier blobs are always there because we never delete them,
        // and anyway it's impossible to check without waiting 4 hours for an inventory.
        return [NSNumber numberWithBool:YES];
    }
    
    if (theStorageType != StorageTypeS3 && theStorageType != StorageTypeS3Glacier) {
        HSLogError(@"containsObjectForSHA1: storage type %ld for blob %@ is unknown; returning NO", (unsigned long)theStorageType, theSHA1);
        return [NSNumber numberWithBool:NO];
    }
    
    NSAssert(theStorageType == StorageTypeS3 || theStorageType == StorageTypeS3Glacier, @"must be S3 or S3Glacier");
    
    BOOL contains = NO;
    NSNumber *targetContains = [targetConnection fileExistsAtPath:[self objectPathForSHA1:theSHA1 storageType:theStorageType] dataSize:dataSize delegate:targetConnectionDelegate error:error];
    if (targetContains == nil) {
        return nil;
    }
    contains = [targetContains boolValue];
    
    if (!contains) {
        HSLogDebug(@"%@ does not exist", [self objectPathForSHA1:theSHA1 storageType:theStorageType]);
    }
    
    if (!contains && ([target targetType] == kTargetLocal)) {
        for (NSString *path in [self pathsToTryForSHA1:theSHA1]) {
            targetContains = [targetConnection fileExistsAtPath:path dataSize:dataSize delegate:targetConnectionDelegate error:error];
            if (targetContains == nil) {
                return nil;
            }
            contains = [targetContains boolValue];
            if (contains) {
                break;
            }
        }
    }
    return [NSNumber numberWithBool:contains];
}
- (NSNumber *)isObjectDownloadableForSHA1:(NSString *)theSHA1 storageType:(StorageType)theStorageType error:(NSError **)error {
    NSNumber *ret = nil;
    if (theStorageType == StorageTypeGlacier) {
        ret = [NSNumber numberWithBool:NO];
    } else if (theStorageType == StorageTypeS3) {
        ret = [targetConnection fileExistsAtPath:[self objectPathForSHA1:theSHA1 storageType:theStorageType] dataSize:NULL delegate:targetConnectionDelegate error:error];
    } else if (theStorageType == StorageTypeS3Glacier) {
        ret = [targetConnection isObjectRestoredAtPath:[self objectPathForSHA1:theSHA1 storageType:theStorageType] delegate:targetConnectionDelegate error:error];
    } else {
        SETNSERROR([self errorDomain], -1, @"unknown storage type");
    }
    return ret;
}
- (BOOL)restoreObjectForSHA1:(NSString *)theSHA1 forDays:(NSUInteger)theDays tier:(int)theGlacierRetrievalTier storageType:(StorageType)theStorageType alreadyRestoredOrRestoring:(BOOL *)alreadyRestoredOrRestoring error:(NSError **)error {
    NSError *myError = nil;
    if (![targetConnection restoreObjectAtPath:[self objectPathForSHA1:theSHA1 storageType:theStorageType] forDays:theDays tier:theGlacierRetrievalTier alreadyRestoredOrRestoring:alreadyRestoredOrRestoring delegate:targetConnectionDelegate error:&myError]) {
        SETERRORFROMMYERROR;
        if ([myError isErrorWithDomain:[S3Service errorDomain] code:ERROR_NOT_FOUND]) {
            SETNSERROR([self errorDomain], ERROR_NOT_FOUND, @"object %@ can't be restored because it's not found", theSHA1);
        }
        return NO;
    }
    return YES;
}
- (NSData *)dataForSHA1:(NSString *)theSHA1 storageType:(StorageType)theStorageType error:(NSError **)error {
    return [self dataWithRange:NSMakeRange(NSNotFound, 0) forSHA1:theSHA1 storageType:theStorageType refreshCache:NO error:error];
}
- (NSData *)dataForSHA1:(NSString *)theSHA1 storageType:(StorageType)theStorageType refreshCache:(BOOL)refreshCache error:(NSError **)error {
    return [self dataWithRange:NSMakeRange(NSNotFound, 0) forSHA1:theSHA1 storageType:theStorageType refreshCache:refreshCache error:error];
}
- (NSData *)dataWithRange:(NSRange)theRange forSHA1:(NSString *)theSHA1 storageType:(StorageType)theStorageType error:(NSError **)error {
    return [self dataWithRange:theRange forSHA1:theSHA1 storageType:theStorageType refreshCache:NO error:error];
}

- (NSData *)dataWithRange:(NSRange)theRange forSHA1:(NSString *)theSHA1 storageType:(StorageType)theStorageType refreshCache:(BOOL)refreshCache error:(NSError **)error {
    if (refreshCache) {
        NSAssert(theStorageType == StorageTypeS3 || theStorageType == StorageTypeS3Glacier, @"must be S3 or S3Glacier");
        NSString *prefix = (theStorageType == StorageTypeS3) ? @"" : @"glacier/";
        NSArray *dirs = [NSArray arrayWithObjects:[NSString stringWithFormat:@"%@/%@%@/objects", [self pathPrefix], prefix, computerUUID],
                         [NSString stringWithFormat:@"%@/%@%@/objects2", [self pathPrefix], prefix, computerUUID],
                         nil];
        for (NSString *dir in dirs) {
            if (![targetConnection clearCachedItemsForDirectory:dir error:error]) {
                return nil;
            }
        }
    }
    NSError *myError = nil;
    NSData *ret = [targetConnection contentsOfRange:theRange ofFileAtPath:[self objectPathForSHA1:theSHA1 storageType:theStorageType] delegate:targetConnectionDelegate error:&myError];
    if (ret == nil && [myError code] == ERROR_NOT_FOUND) {
        for (NSString *path in [self pathsToTryForSHA1:theSHA1]) {
            ret = [targetConnection contentsOfRange:theRange ofFileAtPath:path delegate:targetConnectionDelegate error:&myError];
            if (ret != nil) {
                break;
            }
            if (ret == nil && [myError code] != ERROR_NOT_FOUND) {
                break;
            }
        }
    }
    if (ret == nil) {
        SETERRORFROMMYERROR;
        if ([myError code] == ERROR_NOT_FOUND) {
            SETNSERROR([self errorDomain], ERROR_NOT_FOUND, @"object not found at target for SHA1 %@", theSHA1);
        }
        if ([myError isErrorWithDomain:[S3Service errorDomain] code:S3SERVICE_ERROR_AMAZON_ERROR] && [[[myError userInfo] objectForKey:@"AmazonCode"] isEqualToString:@"InvalidObjectState"]) {
            SETNSERROR([self errorDomain], ERROR_NOT_DOWNLOADABLE, @"S3 object %@ not downloadable", theSHA1);
        }
    }
    return ret;
}

- (NSString *)checksumOfObjectWithSHA1:(NSString *)theSHA1 storageType:(StorageType)theStorageType error:(NSError **)error {
    NSError *myError = nil;
    NSString *ret = [targetConnection checksumOfFileAtPath:[self objectPathForSHA1:theSHA1 storageType:theStorageType] delegate:targetConnectionDelegate error:&myError];
    if (ret == nil && [myError code] == ERROR_NOT_FOUND) {
        for (NSString *path in [self pathsToTryForSHA1:theSHA1]) {
            ret = [targetConnection checksumOfFileAtPath:path delegate:targetConnectionDelegate error:&myError];
            if (ret != nil) {
                break;
            }
            if (ret == nil && [myError code] != ERROR_NOT_FOUND) {
                break;
            }
        }
    }
    if (ret == nil) {
        SETERRORFROMMYERROR;
        if ([myError code] == ERROR_NOT_FOUND) {
            SETNSERROR([self errorDomain], ERROR_NOT_FOUND, @"object not found at target for SHA1 %@", theSHA1);
        }
        if ([myError isErrorWithDomain:[S3Service errorDomain] code:S3SERVICE_ERROR_AMAZON_ERROR] && [[[myError userInfo] objectForKey:@"AmazonCode"] isEqualToString:@"InvalidObjectState"]) {
            SETNSERROR([self errorDomain], ERROR_NOT_DOWNLOADABLE, @"S3 object %@ not downloadable", theSHA1);
        }
    }
    return ret;
}

- (BOOL)putData:(NSData *)theData forSHA1:(NSString *)theSHA1 storageType:(StorageType)theStorageType error:(NSError **)error {
    return [self putData:theData forSHA1:theSHA1 storageType:theStorageType dataTransferDelegate:nil error:error];
}
- (BOOL)putData:(NSData *)theData forSHA1:(NSString *)theSHA1 storageType:(StorageType)theStorageType dataTransferDelegate:(id <DataTransferDelegate>)theDelegate error:(NSError **)error {
    NSString *s3Path = [self objectPathForSHA1:theSHA1 storageType:theStorageType];
    if (![targetConnection writeData:theData toFileAtPath:s3Path dataTransferDelegate:theDelegate targetConnectionDelegate:targetConnectionDelegate error:error]) {
        return NO;
    }
    return YES;
}

- (NSSet *)packIdsForPackSet:(NSString *)packSetName storageType:(StorageType)theStorageType error:(NSError **)error {
    NSString *packsetDir = [self packSetDirForPackSetName:packSetName storageType:theStorageType];
    NSDictionary *itemsByName = [targetConnection itemsByNameAtPath:packsetDir targetConnectionDelegate:targetConnectionDelegate error:error];
    if (itemsByName == nil) {
        return nil;
    }
    
    NSString *regex = @"^([^/]+).pack$";
    NSMutableSet *ret = [NSMutableSet set];
    for (Item *item in [itemsByName allValues]) {
        if ([item.name isMatchedByRegex:regex]) {
            NSString *packSHA1 = [item.name substringWithRange:[item.name rangeOfRegex:regex capture:1]];
            PackId *packId = [[PackId alloc] initWithPackSetName:packSetName packSHA1:packSHA1];
            [ret addObject:packId];
            [packId release];
        }
    }
    return ret;
}
- (BOOL)clearCachedPackIdsForPackSet:(NSString *)thePackSetName storageType:(StorageType)theStorageType error:(NSError **)error {
    NSString *packsetDir = [self packSetDirForPackSetName:thePackSetName storageType:theStorageType];
    return [targetConnection clearCachedItemsForDirectory:packsetDir error:error];
}

- (NSString *)packSetDirForPackSetName:(NSString *)packSetName storageType:(StorageType)theStorageType {
    NSAssert(theStorageType == StorageTypeS3 || theStorageType == StorageTypeS3Glacier, @"must be S3 or S3Glacier");
    NSString *s3GlacierPrefix = theStorageType == StorageTypeS3Glacier ? @"glacier/" : @"";
    NSString *packsetDir = [NSString stringWithFormat:@"%@/%@%@/packsets/%@", [self pathPrefix], s3GlacierPrefix, computerUUID, packSetName];
    return packsetDir;
}

- (NSData *)indexDataForPackId:(PackId *)thePackId error:(NSError **)error {
    NSString *s3Path = [self s3PathForPackId:thePackId suffix:@"index" storageType:StorageTypeS3];
    NSError *myError = nil;
    NSData *ret = [targetConnection contentsOfFileAtPath:s3Path delegate:targetConnectionDelegate error:&myError];
    if(ret == nil) {
        SETERRORFROMMYERROR;
        if ([myError code] == ERROR_NOT_FOUND) {
            SETNSERROR([self errorDomain], ERROR_NOT_FOUND, @"%@ not found at destination", s3Path);
        }
    }
    return ret;
}
- (BOOL)putIndexData:(NSData *)theData forPackId:(PackId *)thePackId error:(NSError **)error {
    return [self putData:theData forPackId:thePackId suffix:@"index" storageType:StorageTypeS3 saveToCache:NO error:error];
}
- (BOOL)deleteIndex:(PackId *)thePackId error:(NSError **)error {
    return [self deleteDataForPackId:thePackId suffix:@"index" storageType:StorageTypeS3 error:error];
}

- (NSNumber *)isPackDownloadableWithId:(PackId *)packId storageType:(StorageType)theStorageType error:(NSError **)error {
    NSNumber *ret = nil;
    NSString *s3Path = [self s3PathForPackId:packId suffix:@"pack" storageType:theStorageType];
    if (theStorageType == StorageTypeGlacier) {
        ret = [NSNumber numberWithBool:NO];
    } else if (theStorageType == StorageTypeS3) {
        ret = [targetConnection fileExistsAtPath:s3Path dataSize:NULL delegate:targetConnectionDelegate error:error];
    } else if (theStorageType == StorageTypeS3Glacier) {
        if ([downloadablePackIds containsObject:packId]) {
            ret = [NSNumber numberWithBool:YES];
        } else {
            ret = [targetConnection isObjectRestoredAtPath:s3Path delegate:targetConnectionDelegate error:error];
            if ([ret boolValue]) {
                [downloadablePackIds addObject:packId];
            }
        }
    } else {
        SETNSERROR([self errorDomain], -1, @"unknown storage type");
    }
    return ret;
}
- (BOOL)restorePackWithId:(PackId *)packId forDays:(NSUInteger)theDays tier:(int)theGlacierRetrievalTier storageType:(StorageType)theStorageType alreadyRestoredOrRestoring:(BOOL *)alreadyRestoredOrRestoring error:(NSError **)error {
    if (![packIdsAlreadyPostedForRestore containsObject:packId]) {
        NSError *myError = nil;
        if (![targetConnection restoreObjectAtPath:[self s3PathForPackId:packId suffix:@"pack" storageType:theStorageType] forDays:theDays tier:theGlacierRetrievalTier alreadyRestoredOrRestoring:alreadyRestoredOrRestoring delegate:targetConnectionDelegate error:&myError]) {
            SETERRORFROMMYERROR;
            if ([myError isErrorWithDomain:[S3Service errorDomain] code:ERROR_NOT_FOUND]) {
                SETNSERROR([self errorDomain], ERROR_NOT_FOUND, @"pack %@ can't be restored because it's not found", packId);
            }
            return NO;
        }
        [packIdsAlreadyPostedForRestore addObject:packId];
    } else {
        HSLogDebug(@"already requested %@", packId);
    }
    return YES;
}

- (NSData *)packDataForPackId:(PackId *)thePackId storageType:(StorageType)theStorageType error:(NSError **)error {
    return [self dataForPackId:thePackId suffix:@"pack" storageType:theStorageType error:error];
}
- (NSData *)dataForPackIndexEntry:(PackIndexEntry *)thePIE storageType:(StorageType)theStorageType error:(NSError **)error {
    NSData *ret = [self cachedPackDataForPackIndexEntry:thePIE storageType:theStorageType error:NULL];
    if (ret == nil) {
        NSData *packData = [self packDataForPackId:[thePIE packId] storageType:theStorageType error:error];
        if (packData == nil) {
            return nil;
        }
        if ([packData length] == 0) {
            SETNSERROR([self errorDomain], -1, @"packData for %@ is empty!", thePIE);
            return nil;
        }
        HSLogDebug(@"found data for %@ (target %@, computer %@)", thePIE, [target endpoint], computerUUID);
        if ([thePIE offset] > INT_MAX) {
            HSLogError(@"invalid pack index entry offset value for %@", thePIE);
            SETNSERROR([self errorDomain], -1, @"invalid pack index entry offset value %qu", [thePIE offset]);
            return nil;
        }
        
        if ([packData length] < [thePIE offset]) {
            HSLogError(@"pack index entry offset is greater than pack data length %ld for %@", [packData length], thePIE);
            SETNSERROR([self errorDomain], -1, @"invalid pack index entry offset value %qu is greater than pack data length %ld", [thePIE offset], [packData length]);
            return nil;
        }
        
        NSData *subdata = [packData subdataWithRange:NSMakeRange([thePIE offset], [packData length] - [thePIE offset])];
        DataInputStream *dis = [[[DataInputStream alloc] initWithData:subdata description:@"blob"] autorelease];
        BufferedInputStream *bis = [[[BufferedInputStream alloc] initWithUnderlyingStream:dis] autorelease];
        ret = [self packDataFromBufferedInputStream:bis error:error];
    }
    return ret;
}
- (BOOL)putPackData:(NSData *)theData forPackId:(PackId *)thePackId storageType:(StorageType)theStorageType saveToCache:(BOOL)saveToCache error:(NSError **)error {
    return [self putData:theData forPackId:thePackId suffix:@"pack" storageType:theStorageType saveToCache:saveToCache error:error];
}
- (BOOL)deletePack:(PackId *)thePackId storageType:(StorageType)theStorageType error:(NSError **)error {
    return [self deleteDataForPackId:thePackId suffix:@"pack" storageType:theStorageType error:error];
}
- (BOOL)putReflogItem:(NSData *)itemData forBucketUUID:(NSString *)theBucketUUID error:(NSError **)error {
    NSString *s3Path = [NSString stringWithFormat:@"%@/%@/bucketdata/%@/refs/logs/master/%0.0f", [self pathPrefix], computerUUID, theBucketUUID, [NSDate timeIntervalSinceReferenceDate]];
    return [targetConnection writeData:itemData toFileAtPath:s3Path dataTransferDelegate:nil targetConnectionDelegate:targetConnectionDelegate error:error];
}
- (BOOL)deleteObjectForSHA1:(NSString *)theSHA1 storageType:(StorageType)theStorageType error:(NSError **)error {
    if (theStorageType == StorageTypeGlacier) {
        // We assume that Glacier blobs are always there because we never delete them,
        // and anyway it's impossible to check without waiting 4 hours for an inventory.
        return YES;
    }
    
    if (theStorageType != StorageTypeS3 && theStorageType != StorageTypeS3Glacier) {
        HSLogError(@"containsObjectForSHA1: storage type %ld for blob %@ is unknown; returning NO", (unsigned long)theStorageType, theSHA1);
        SETNSERROR([self errorDomain], -1, @"unknown storage type; can't delete");
        return NO;
    }
    
    NSAssert(theStorageType == StorageTypeS3 || theStorageType == StorageTypeS3Glacier, @"must be S3 or S3Glacier");
    
    if (![targetConnection removeItemAtPath:[self objectPathForSHA1:theSHA1 storageType:theStorageType] delegate:targetConnectionDelegate error:error]) {
        return NO;
    }

    if ([target targetType] == kTargetLocal) {
        for (NSString *path in [self pathsToTryForSHA1:theSHA1]) {
            if (![targetConnection removeItemAtPath:path delegate:targetConnectionDelegate error:error]) {
                return NO;
            }
        }
    }
    return YES;
}


#pragma mark internal
- (NSArray *)objectsDirectories {
    return [NSArray arrayWithObjects:
            [NSString stringWithFormat:@"%@/%@/objects", [self pathPrefix], computerUUID],
            [NSString stringWithFormat:@"%@/%@/objects2", [self pathPrefix], computerUUID],
            [NSString stringWithFormat:@"%@/glacier/%@/objects", [self pathPrefix], computerUUID], nil];
}
- (BOOL)ensureCacheIsLoadedForDirectory:(NSString *)theDirectory error:(NSError **)error {
    NSDictionary *items = [targetConnection itemsByNameAtPath:theDirectory targetConnectionDelegate:targetConnectionDelegate error:error];
    if (items == nil) {
        return NO;
    }
    for (Item *item in [items allValues]) {
        if (item.isDirectory) {
            NSString *childDir = [theDirectory stringByAppendingPathComponent:item.name];
            if (![self ensureCacheIsLoadedForDirectory:childDir error:error]) {
                return NO;
            }
        }
    }
    return YES;
}
- (NSArray *)pathsToTryForSHA1:(NSString *)theSHA1 storageType:(StorageType)theStorageType {
    NSMutableArray *pathsToTry = [NSMutableArray array];
    [pathsToTry addObject:[self objectPathForSHA1:theSHA1 storageType:theStorageType]];
    return pathsToTry;
}
- (NSString *)masterPathForBucketUUID:(NSString *)theBucketUUID {
    return [NSString stringWithFormat:@"%@/%@/bucketdata/%@/refs/heads/master", [self pathPrefix], computerUUID, theBucketUUID];
}
- (NSString *)objectPathForSHA1:(NSString *)theSHA1 storageType:(StorageType)theStorageType {
    if (([target targetType] == kTargetLocal) && [theSHA1 length] == 40) {
        return [NSString stringWithFormat:@"%@/%@/objects/%@/%@", [self pathPrefix], computerUUID, [theSHA1 substringToIndex:2], [theSHA1 substringFromIndex:2]];
    }

    NSAssert(theStorageType == StorageTypeS3 || theStorageType == StorageTypeS3Glacier, @"must be S3 or S3Glacier");
    NSString *prefix = (theStorageType == StorageTypeS3) ? @"" : @"glacier/";
    
    return [NSString stringWithFormat:@"%@/%@%@/objects/%@", [self pathPrefix], prefix, computerUUID, theSHA1];
}
- (NSArray *)pathsToTryForSHA1:(NSString *)theSHA1 {
    NSMutableArray *ret = [NSMutableArray array];
    [ret addObject:[NSString stringWithFormat:@"%@/%@/objects/%@/%@", [self pathPrefix], computerUUID, [theSHA1 substringToIndex:2], [theSHA1 substringFromIndex:2]]];
    [ret addObject:[NSString stringWithFormat:@"%@/%@/objects2/%@/%@", [self pathPrefix], computerUUID, [theSHA1 substringToIndex:2], [theSHA1 substringFromIndex:2]]];
    [ret addObject:[NSString stringWithFormat:@"%@/%@/objects/%@", [self pathPrefix], computerUUID, theSHA1]];
    [ret addObject:[NSString stringWithFormat:@"%@/%@/objects/%@/%@/%@", [self pathPrefix], computerUUID, [theSHA1 substringToIndex:2], [theSHA1 substringWithRange:NSMakeRange(2, 2)], [theSHA1 substringFromIndex:4]]];
    [ret addObject:[NSString stringWithFormat:@"%@/%@/objects2/%@/%@/%@", [self pathPrefix], computerUUID, [theSHA1 substringToIndex:2], [theSHA1 substringWithRange:NSMakeRange(2, 2)], [theSHA1 substringFromIndex:4]]];
    return ret;
}
- (NSString *)legacy1SFTPObjectPathForSHA1:(NSString *)theSHA1 {
    return [NSString stringWithFormat:@"%@/%@/objects/%@", [self pathPrefix], computerUUID, theSHA1];
}
- (NSString *)legacy2SFTPObjectPathForSHA1:(NSString *)theSHA1 {
    return [NSString stringWithFormat:@"%@/%@/objects/%@/%@/%@", [self pathPrefix], computerUUID, [theSHA1 substringToIndex:2], [theSHA1 substringWithRange:NSMakeRange(2, 2)], [theSHA1 substringFromIndex:4]];
}
- (NSString *)legacy1DropboxObjectPathForSHA1:(NSString *)theSHA1 {
    return [NSString stringWithFormat:@"%@/%@/objects/%@/%@/%@", [self pathPrefix], computerUUID, [theSHA1 substringToIndex:2], [theSHA1 substringWithRange:NSMakeRange(2, 2)], [theSHA1 substringFromIndex:4]];
}
- (NSString *)legacy2DropboxObjectPathForSHA1:(NSString *)theSHA1 {
    return [NSString stringWithFormat:@"%@/%@/objects/%@", [self pathPrefix], computerUUID, theSHA1];
}
- (NSString *)legacy3DropboxObjectPathForSHA1:(NSString *)theSHA1 {
    return [NSString stringWithFormat:@"%@/%@/objects/%@/%@", [self pathPrefix], computerUUID, [theSHA1 substringToIndex:2], [theSHA1 substringFromIndex:2]];
}
- (NSString *)legacyAmazonDriveObjectPathForSHA1:(NSString *)theSHA1 {
    return [NSString stringWithFormat:@"%@/%@/objects/%@", [self pathPrefix], computerUUID, theSHA1];
}
- (NSString *)legacy1OneDriveObjectPathForSHA1:(NSString *)theSHA1 {
    return [NSString stringWithFormat:@"%@/%@/objects/%@/%@", [self pathPrefix], computerUUID, [theSHA1 substringToIndex:2], [theSHA1 substringFromIndex:2]];
}
- (NSString *)legacy2OneDriveObjectPathForSHA1:(NSString *)theSHA1 {
    return [NSString stringWithFormat:@"%@/%@/objects/%@", [self pathPrefix], computerUUID, theSHA1];
}
- (NSData *)cachedPackDataForPackIndexEntry:(PackIndexEntry *)thePIE storageType:(StorageType)theStorageType error:(NSError **)error {
    NSString *cachePath = [self cachePathForPackId:[thePIE packId] suffix:@"pack" storageType:theStorageType];
    int fd = open([cachePath fileSystemRepresentation], O_RDONLY);
    if (fd == -1) {
        int errnum = errno;
        if (errnum == ENOENT) {
            SETNSERROR([self errorDomain], ERROR_NOT_FOUND, @"pack not found for %@", thePIE);
        } else {
            HSLogError(@"open(%@) error %d: %s", cachePath, errnum, strerror(errnum));
            SETNSERROR(@"UnixErrorDomain", errnum, @"failed to open %@: %s", cachePath, strerror(errnum));
        }
        return nil;
    }
    NSData *ret = nil;
    FDInputStream *fdis = [[FDInputStream alloc] initWithFD:fd label:cachePath];
    BufferedInputStream *bis = [[BufferedInputStream alloc] initWithUnderlyingStream:fdis];
    do {
        if (lseek(fd, [thePIE offset], SEEK_SET) == -1) {
            int errnum = errno;
            HSLogError(@"lseek(%@, %qu) error %d: %s", cachePath, [thePIE offset], errnum, strerror(errnum));
            SETNSERROR(@"UnixErrorDomain", errnum, @"failed to seek to %qu in %@: %s", [thePIE offset], cachePath, strerror(errnum));
            break;
        }
        ret = [self packDataFromBufferedInputStream:bis error:error];
    } while (0);
    close(fd);
    [bis release];
    [fdis release];
    
//    if (ret != nil) {
//        HSLogDebug(@"found cached pack data for %@ at %@", thePIE, cachePath);
//    }
    return ret;
}
- (NSData *)packDataFromBufferedInputStream:(BufferedInputStream *)bis error:(NSError **)error {
    NSString *mimeType; // Unused.
    NSString *downloadName; // Unused.
    NSError *myError = nil;
    if (![StringIO read:&mimeType from:bis error:&myError]
        || ![StringIO read:&downloadName from:bis error:&myError]) {
        SETERRORFROMMYERROR;
        HSLogError(@"error reading mimeType or downloadName from buffered input stream: %@", myError);
        if ([myError code] == ERROR_ABSURD_STRING_LENGTH) {
            SETNSERROR([self errorDomain], ERROR_INVALID_PACK_INDEX_ENTRY, @"invalid pack index entry offset -- %@", [myError localizedDescription]);
        }
        return nil;
    }
    uint64_t dataLen = 0;
    if (![IntegerIO readUInt64:&dataLen from:bis error:error]) {
        return nil;
    }
    NSData *data = nil;
    if (dataLen > 0) {
        unsigned char *buf = (unsigned char *)malloc((size_t)dataLen);
        if (![bis readExactly:(NSUInteger)dataLen into:buf error:error]) {
            free(buf);
            return nil;
        }
        data = [NSData dataWithBytesNoCopy:buf length:(NSUInteger)dataLen];
    } else {
        data = [NSData data];
    }
    return data;
}
- (NSData *)dataForPackId:(PackId *)thePackId suffix:(NSString *)theSuffix storageType:(StorageType)theStorageType error:(NSError **)error {
    NSString *cachePath = [self cachePathForPackId:thePackId suffix:theSuffix storageType:theStorageType];
    NSData *ret = [NSData dataWithContentsOfFile:cachePath options:NSUncachedRead error:error];
//    if (ret != nil) {
//        HSLogDebug(@"found %@ %@ cached at %@", thePackId, theSuffix, cachePath);
//    }
    
    BOOL foundInCache = ret != nil;
    if (ret == nil) {
        HSLogDetail(@"downloading %@ %@", theSuffix, thePackId);
        NSString *s3Path = [self s3PathForPackId:thePackId suffix:theSuffix storageType:theStorageType];
        NSError *myError = nil;
        ret = [targetConnection contentsOfFileAtPath:s3Path delegate:targetConnectionDelegate error:&myError];
        if(ret == nil) {
            SETERRORFROMMYERROR;
            if ([myError code] == ERROR_NOT_FOUND) {
                SETNSERROR([self errorDomain], ERROR_NOT_FOUND, @"%@ not found at destination", s3Path);
            }
        }
    }
    if (ret != nil && !foundInCache) {
        NSError *myError = nil;
        if (![[NSFileManager defaultManager] ensureParentPathExistsForPath:cachePath targetUID:[[CacheOwnership sharedCacheOwnership] uid] targetGID:[[CacheOwnership sharedCacheOwnership] gid] error:&myError]
            || ![Streams writeData:ret atomicallyToFile:cachePath targetUID:[[CacheOwnership sharedCacheOwnership] uid] targetGID:[[CacheOwnership sharedCacheOwnership] gid] bytesWritten:NULL error:&myError]) {
            HSLogError(@"error writing cache file %@: %@", cachePath, myError);
//        } else {
//            HSLogDebug(@"cached %@ %@ at %@", thePackId, theSuffix, cachePath);
        }
    }
    return ret;
}
- (BOOL)putData:(NSData *)theData forPackId:(PackId *)thePackId suffix:(NSString *)theSuffix storageType:(StorageType)theStorageType saveToCache:(BOOL)saveToCache error:(NSError **)error {
    NSString *s3Path = [self s3PathForPackId:thePackId suffix:theSuffix storageType:theStorageType];
    HSLogInfo(@"writing %@ %@ (%ld bytes)", theSuffix, s3Path, [theData length]);
    if (![targetConnection writeData:theData toFileAtPath:s3Path dataTransferDelegate:nil targetConnectionDelegate:targetConnectionDelegate error:error]) {
        return NO;
    }
    
    if (saveToCache) {
        NSError *myError = nil;
        NSString *cachePath = [self cachePathForPackId:thePackId suffix:theSuffix storageType:theStorageType];
        if (![[NSFileManager defaultManager] ensureParentPathExistsForPath:cachePath targetUID:[[CacheOwnership sharedCacheOwnership] uid] targetGID:[[CacheOwnership sharedCacheOwnership] gid] error:&myError]
            || ![Streams writeData:theData atomicallyToFile:cachePath targetUID:[[CacheOwnership sharedCacheOwnership] uid] targetGID:[[CacheOwnership sharedCacheOwnership] gid] bytesWritten:NULL error:&myError]) {
            HSLogError(@"error writing cache file %@: %@", cachePath, myError);
        }
    }
    
    return YES;
}
- (BOOL)deleteDataForPackId:(PackId *)thePackId suffix:(NSString *)theSuffix storageType:(StorageType)theStorageType error:(NSError **)error {
    NSAssert(theStorageType == StorageTypeS3 || theStorageType == StorageTypeS3Glacier, @"must be S3 or S3Glacier");
    
    NSError *myError = nil;
    NSString *cachePath = [self cachePathForPackId:thePackId suffix:theSuffix storageType:theStorageType];
    BOOL isDir;
    if ([[NSFileManager defaultManager] fileExistsAtPath:cachePath isDirectory:&isDir] && ![[NSFileManager defaultManager] removeItemAtPath:cachePath error:&myError]) {
        HSLogError(@"failed to delete %@: %@", cachePath, myError);
    }

    NSString *s3Path = [self s3PathForPackId:thePackId suffix:theSuffix storageType:theStorageType];
    HSLogInfo(@"deleting %@ %@", theSuffix, s3Path);
    return [targetConnection removeItemAtPath:s3Path delegate:targetConnectionDelegate error:error];
}
- (NSString *)cachePathForPackId:(PackId *)thePackId suffix:(NSString *)theSuffix storageType:(StorageType)theStorageType {
    NSAssert(theStorageType == StorageTypeS3 || theStorageType == StorageTypeS3Glacier, @"must be S3 or S3Glacier");
    NSString *s3GlacierPrefix = theStorageType == StorageTypeS3Glacier ? @"/glacier" : @"";

    return [NSString stringWithFormat:@"%@/%@%@/%@/packsets/%@/%@/%@.%@",
            [UserLibrary arqCachePath],
            [target targetUUID],
            s3GlacierPrefix,
            computerUUID,
            [thePackId packSetName],
            [[thePackId packSHA1] substringToIndex:2],
            [[thePackId packSHA1] substringFromIndex:2],
            theSuffix];
}
- (NSString *)s3PathForPackId:(PackId *)thePackId suffix:(NSString *)theSuffix storageType:(StorageType)theStorageType {
    NSAssert(theStorageType == StorageTypeS3 || theStorageType == StorageTypeS3Glacier, @"must be S3 or S3Glacier");
    NSString *s3GlacierPrefix = theStorageType == StorageTypeS3Glacier ? @"glacier/" : @"";
    
    return [NSString stringWithFormat:@"%@/%@%@/packsets/%@/%@.%@", [self pathPrefix], s3GlacierPrefix, computerUUID, [thePackId packSetName], [thePackId packSHA1], theSuffix];
}

- (NSString *)pathPrefix {
    NSString *ret = [[target endpoint] path];
    if ([ret isEqualToString:@"/"]) {
        ret = @"";
    }
    return ret;
}
@end
