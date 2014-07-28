/*
 Copyright (c) 2009-2014, Stefan Reitshamer http://www.haystacksoftware.com
 
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


#import "FarkImpl.h"
#import "S3AuthorizationProvider.h"
#import "S3Service.h"
#import "Target.h"
#import "SFTPTargetConnection.h"
#import "S3TargetConnection.h"
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


@implementation FarkImpl
- (id)initWithTarget:(Target *)theTarget
        computerUUID:(NSString *)theComputerUUID
targetConnectionDelegate:(id <TargetConnectionDelegate>)theTargetConnectionDelegate
           targetUID:(uid_t)theTargetUID
           targetGID:(gid_t)theTargetGID {
    if (self = [super init]) {
        target = [theTarget retain];
        targetConnection = [target newConnection];
        computerUUID = [theComputerUUID retain];
        targetConnectionDelegate = theTargetConnectionDelegate;
        uid = theTargetUID;
        gid = theTargetGID;
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
    return [[[BlobKey alloc] initWithSHA1:sha1 storageType:StorageTypeS3 stretchEncryptionKey:stretch compressed:NO error:error] autorelease];
}
- (BOOL)setHeadBlobKey:(BlobKey *)theHeadBlobKey forBucketUUID:(NSString *)theBucketUUID error:(NSError **)error {
    NSMutableString *str = [NSMutableString stringWithString:[theHeadBlobKey sha1]];
    if ([theHeadBlobKey stretchEncryptionKey]) {
        [str appendString:@"Y"];
    }
    NSData *data = [str dataUsingEncoding:NSUTF8StringEncoding];
    return [targetConnection writeData:data toFileAtPath:[self masterPathForBucketUUID:theBucketUUID] dataTransferDelegate:nil targetConnectionDelegate:targetConnectionDelegate error:error];
}
- (BOOL)deleteHeadBlobKeyForBucketUUID:(NSString *)theBucketUUID error:(NSError **)error {
    return [targetConnection removeItemAtPath:[self masterPathForBucketUUID:theBucketUUID] delegate:targetConnectionDelegate error:error];
}
- (NSNumber *)containsObjectForSHA1:(NSString *)theSHA1 storageType:(StorageType)theStorageType dataSize:(unsigned long long *)dataSize forceTargetCheck:(BOOL)forceTargetCheck error:(NSError **)error {
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
    if (!contains && ([target targetType] == kTargetSFTP)) {
        // We used to write all objects in the same dir for SFTP, just like we do for S3.
        targetContains = [targetConnection fileExistsAtPath:[self legacy1SFTPObjectPathForSHA1:theSHA1] dataSize:dataSize delegate:targetConnectionDelegate error:error];
        if (targetContains == nil) {
            return nil;
        }
        contains = [targetContains boolValue];
    }
    if (!contains && ([target targetType] == kTargetSFTP)) {
        // Version 2 wrote objects in dir1/dir2 form, but that resulted in too many opendir() calls.
        targetContains = [targetConnection fileExistsAtPath:[self legacy2SFTPObjectPathForSHA1:theSHA1] dataSize:dataSize delegate:targetConnectionDelegate error:error];
        if (targetContains == nil) {
            return nil;
        }
        contains = [targetContains boolValue];
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
- (BOOL)restoreObjectForSHA1:(NSString *)theSHA1 forDays:(NSUInteger)theDays storageType:(StorageType)theStorageType alreadyRestoredOrRestoring:(BOOL *)alreadyRestoredOrRestoring error:(NSError **)error {
    NSError *myError = nil;
    if (![targetConnection restoreObjectAtPath:[self objectPathForSHA1:theSHA1 storageType:theStorageType] forDays:theDays alreadyRestoredOrRestoring:alreadyRestoredOrRestoring delegate:targetConnectionDelegate error:&myError]) {
        SETERRORFROMMYERROR;
        if ([myError isErrorWithDomain:[S3Service errorDomain] code:ERROR_NOT_FOUND]) {
            SETNSERROR([self errorDomain], ERROR_NOT_FOUND, @"object %@ can't be restored because it's not found", theSHA1);
        }
        return NO;
    }
    return YES;
}
- (NSData *)dataForSHA1:(NSString *)theSHA1 storageType:(StorageType)theStorageType error:(NSError **)error {
    NSError *myError = nil;
    NSData *ret = [targetConnection contentsOfFileAtPath:[self objectPathForSHA1:theSHA1 storageType:theStorageType] delegate:targetConnectionDelegate error:&myError];
    if (ret == nil && [myError code] == ERROR_NOT_FOUND && ([target targetType] == kTargetSFTP)) {
        // We used to write all objects in the same dir for SFTP, just like we do for S3.
        ret = [targetConnection contentsOfFileAtPath:[self legacy1SFTPObjectPathForSHA1:theSHA1] delegate:targetConnectionDelegate error:&myError];
    }
    if (ret == nil && [myError code] == ERROR_NOT_FOUND && ([target targetType] == kTargetSFTP)) {
        // Version 2 wrote objects in dir1/dir2 form, but that resulted in too many opendir() calls.
        ret = [targetConnection contentsOfFileAtPath:[self legacy2SFTPObjectPathForSHA1:theSHA1] delegate:targetConnectionDelegate error:&myError];
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
    NSAssert(theStorageType == StorageTypeS3 || theStorageType == StorageTypeS3Glacier, @"must be S3 or S3Glacier");
    NSString *s3GlacierPrefix = theStorageType == StorageTypeS3Glacier ? @"glacier/" : @"";
    NSString *thePrefix = [NSString stringWithFormat:@"%@/%@%@/packsets/%@/", [self pathPrefix], s3GlacierPrefix, computerUUID, packSetName];
    NSArray *paths = [targetConnection pathsWithPrefix:thePrefix delegate:targetConnectionDelegate error:error];
    if (paths == nil) {
        return nil;
    }
    return [self packIdsForPackSet:packSetName paths:paths storageType:theStorageType];
}

- (NSData *)indexDataForPackId:(PackId *)thePackId error:(NSError **)error {
    return [self dataForPackId:thePackId suffix:@"index" storageType:StorageTypeS3 error:error];
}
- (BOOL)putIndexData:(NSData *)theData forPackId:(PackId *)thePackId error:(NSError **)error {
    return [self putData:theData forPackId:thePackId suffix:@"index" storageType:StorageTypeS3 saveToCache:YES error:error];
}
- (BOOL)deleteIndex:(PackId *)thePackId error:(NSError **)error {
    return [self deleteDataForPackId:thePackId suffix:@"index" storageType:StorageTypeS3 error:error];
}

- (NSNumber *)sizeOfPackWithId:(PackId *)thePackId storageType:(StorageType)theStorageType error:(NSError **)error {
    NSString *s3Path = [self s3PathForPackId:thePackId suffix:@"pack" storageType:theStorageType];
    NSError *myError = nil;
    NSNumber *ret = [targetConnection sizeOfItemAtPath:s3Path delegate:targetConnectionDelegate error:&myError];
    if (ret == nil) {
        SETERRORFROMMYERROR;
        if ([myError code] == ERROR_NOT_FOUND) {
            SETNSERROR([self errorDomain], ERROR_NOT_FOUND, @"pack %@ not found", thePackId);
        }
    }
    return ret;
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
- (BOOL)restorePackWithId:(PackId *)packId forDays:(NSUInteger)theDays storageType:(StorageType)theStorageType alreadyRestoredOrRestoring:(BOOL *)alreadyRestoredOrRestoring error:(NSError **)error {
    if (![packIdsAlreadyPostedForRestore containsObject:packId]) {
        NSError *myError = nil;
        if (![targetConnection restoreObjectAtPath:[self s3PathForPackId:packId suffix:@"pack" storageType:theStorageType] forDays:theDays alreadyRestoredOrRestoring:alreadyRestoredOrRestoring delegate:targetConnectionDelegate error:&myError]) {
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
        NSData *subdata = [packData subdataWithRange:NSMakeRange([thePIE offset], [packData length] - [thePIE offset])];
        DataInputStream *dis = [[[DataInputStream alloc] initWithData:subdata description:@"blob"] autorelease];
        BufferedInputStream *bis = [[[BufferedInputStream alloc] initWithUnderlyingStream:dis] autorelease];
        NSString *mimeType;
        NSString *downloadName;
        if (![StringIO read:&mimeType from:bis error:error] || ![StringIO read:&downloadName from:bis error:error]) {
            return nil;
        }
        uint64_t dataLen = 0;
        if (![IntegerIO readUInt64:&dataLen from:bis error:error]) {
            return nil;
        }
        if (dataLen > 0) {
            unsigned char *buf = (unsigned char *)malloc((size_t)dataLen);
            if (![bis readExactly:(NSUInteger)dataLen into:buf error:error]) {
                free(buf);
                return nil;
            }
            ret = [NSData dataWithBytesNoCopy:buf length:(NSUInteger)dataLen];
        } else {
            ret = [NSData data];
        }
    }
    return ret;
}
- (BOOL)putPackData:(NSData *)theData forPackId:(PackId *)thePackId storageType:(StorageType)theStorageType saveToCache:(BOOL)saveToCache error:(NSError **)error {
    return [self putData:theData forPackId:thePackId suffix:@"pack" storageType:theStorageType saveToCache:YES error:error];
}
- (BOOL)deletePack:(PackId *)thePackId storageType:(StorageType)theStorageType error:(NSError **)error {
    return [self deleteDataForPackId:thePackId suffix:@"pack" storageType:theStorageType error:error];
}
- (BOOL)putReflogItem:(NSData *)itemData forBucketUUID:(NSString *)theBucketUUID error:(NSError **)error {
    NSString *s3Path = [NSString stringWithFormat:@"%@/%@/bucketdata/%@/refs/logs/master/%0.0f", [self pathPrefix], computerUUID, theBucketUUID, [NSDate timeIntervalSinceReferenceDate]];
    return [targetConnection writeData:itemData toFileAtPath:s3Path dataTransferDelegate:nil targetConnectionDelegate:targetConnectionDelegate error:error];
}


#pragma mark internal
- (NSString *)masterPathForBucketUUID:(NSString *)theBucketUUID {
    return [NSString stringWithFormat:@"%@/%@/bucketdata/%@/refs/heads/master", [self pathPrefix], computerUUID, theBucketUUID];
}
- (NSString *)objectPathForSHA1:(NSString *)theSHA1 storageType:(StorageType)theStorageType {
    if (([target targetType] == kTargetSFTP) && [theSHA1 length] == 40) {
        return [NSString stringWithFormat:@"%@/%@/objects/%@/%@", [self pathPrefix], computerUUID, [theSHA1 substringToIndex:2], [theSHA1 substringFromIndex:2]];
    }

    NSAssert(theStorageType == StorageTypeS3 || theStorageType == StorageTypeS3Glacier, @"must be S3 or S3Glacier");
    NSString *prefix = (theStorageType == StorageTypeS3) ? @"" : @"glacier/";
    
    return [NSString stringWithFormat:@"%@/%@%@/objects/%@", [self pathPrefix], prefix, computerUUID, theSHA1];
}
- (NSString *)legacy1SFTPObjectPathForSHA1:(NSString *)theSHA1 {
    return [NSString stringWithFormat:@"%@/%@/objects/%@", [self pathPrefix], computerUUID, theSHA1];
}
- (NSString *)legacy2SFTPObjectPathForSHA1:(NSString *)theSHA1 {
    return [NSString stringWithFormat:@"%@/%@/objects/%@/%@/%@", [self pathPrefix], computerUUID, [theSHA1 substringToIndex:2], [theSHA1 substringWithRange:NSMakeRange(2, 2)], [theSHA1 substringFromIndex:4]];
}
- (NSSet *)packIdsForPackSet:(NSString *)thePackSetName paths:(NSArray *)paths storageType:(StorageType)theStorageType {
    NSAssert(theStorageType == StorageTypeS3 || theStorageType == StorageTypeS3Glacier, @"must be S3 or S3Glacier");
    NSString *prefix = (theStorageType == StorageTypeS3) ? @"" : @"glacier/";
    NSString *regex = [NSString stringWithFormat:@"^%@/%@%@/packsets/%@/([^/]+).pack$", [self pathPrefix], prefix, computerUUID, thePackSetName];

    NSMutableSet *ret = [NSMutableSet set];
    for (NSString *path in paths) {
        if ([path isMatchedByRegex:regex]) {
            NSString *packSHA1 = [path substringWithRange:[path rangeOfRegex:regex capture:1]];
            PackId *packId = [[PackId alloc] initWithPackSetName:thePackSetName packSHA1:packSHA1];
            [ret addObject:packId];
            [packId release];
        }
    }
    return ret;
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
        NSString *mimeType;
        NSString *downloadName;
        if (![StringIO read:&mimeType from:bis error:error] || ![StringIO read:&downloadName from:bis error:error]) {
            break;
        }
        uint64_t dataLen = 0;
        if (![IntegerIO readUInt64:&dataLen from:bis error:error]) {
            break;
        }
        NSData *data = nil;
        if (dataLen > 0) {
            unsigned char *buf = (unsigned char *)malloc((size_t)dataLen);
            if (![bis readExactly:(NSUInteger)dataLen into:buf error:error]) {
                free(buf);
                break;
            }
            data = [NSData dataWithBytesNoCopy:buf length:(NSUInteger)dataLen];
        } else {
            data = [NSData data];
        }
        ret = data;
    } while (0);
    close(fd);
    [bis release];
    [fdis release];
    return ret;
}
- (NSData *)dataForPackId:(PackId *)thePackId suffix:(NSString *)theSuffix storageType:(StorageType)theStorageType error:(NSError **)error {
    NSString *cachePath = [self cachePathForPackId:thePackId suffix:theSuffix storageType:theStorageType];
    NSData *ret = [NSData dataWithContentsOfFile:cachePath options:NSUncachedRead error:error];
    BOOL foundInCache = ret != nil;
    if (ret == nil) {
        HSLogDebug(@"downloading pack %@", thePackId);
        NSString *s3Path = [self s3PathForPackId:thePackId suffix:theSuffix storageType:theStorageType];
        NSError *myError = nil;
        ret = [targetConnection contentsOfFileAtPath:s3Path delegate:targetConnectionDelegate error:&myError];
        if(ret == nil) {
            SETERRORFROMMYERROR;
            if ([myError isErrorWithDomain:[S3Service errorDomain] code:ERROR_NOT_FOUND]) {
                SETNSERROR([self errorDomain], ERROR_NOT_FOUND, @"%@ not found in S3", s3Path);
            }
        }
    }
    if (ret != nil && !foundInCache) {
        NSError *myError = nil;
        if (![[NSFileManager defaultManager] ensureParentPathExistsForPath:cachePath targetUID:uid targetGID:gid error:&myError]
            || ![Streams writeData:ret atomicallyToFile:cachePath targetUID:uid targetGID:gid bytesWritten:NULL error:&myError]) {
            HSLogError(@"error writing cache file %@: %@", cachePath, myError);
        }
    }
    return ret;
}
- (BOOL)putData:(NSData *)theData forPackId:(PackId *)thePackId suffix:(NSString *)theSuffix storageType:(StorageType)theStorageType saveToCache:(BOOL)saveToCache error:(NSError **)error {
    NSString *s3Path = [self s3PathForPackId:thePackId suffix:theSuffix storageType:theStorageType];
    if (![targetConnection writeData:theData toFileAtPath:s3Path dataTransferDelegate:nil targetConnectionDelegate:targetConnectionDelegate error:error]) {
        return NO;
    }
    
    if (saveToCache) {
        NSError *myError = nil;
        NSString *cachePath = [self cachePathForPackId:thePackId suffix:theSuffix storageType:theStorageType];
        if (![[NSFileManager defaultManager] ensureParentPathExistsForPath:cachePath targetUID:uid targetGID:gid error:&myError]
            || ![Streams writeData:theData atomicallyToFile:cachePath targetUID:uid targetGID:gid bytesWritten:NULL error:&myError]) {
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
