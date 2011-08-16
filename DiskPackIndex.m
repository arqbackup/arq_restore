//
//  DiskPackIndex.m
//  Arq
//
//  Created by Stefan Reitshamer on 12/30/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#include <sys/stat.h>
#include <sys/mman.h>
#include <libkern/OSByteOrder.h>
#import "DiskPackIndex.h"
#import "NSString_extra.h"
#import "SetNSError.h"
#import "BinarySHA1.h"
#import "PackIndexEntry.h"
#import "NSErrorCodes.h"
#import "S3Service.h"
#import "FileOutputStream.h"
#import "Streams.h"
#import "NSFileManager_extra.h"
#import "ServerBlob.h"
#import "S3ObjectReceiver.h"
#import "DiskPack.h"
#import "BlobACL.h"
#import "FileInputStreamFactory.h"
#import "PackIndexWriter.h"
#import "UserLibrary_Arq.h"
#import "NSError_extra.h"
#import "RegexKitLite.h"

typedef struct index_object {
    uint64_t nbo_offset;
    uint64_t nbo_datalength;
    unsigned char sha1[20];
    unsigned char filler[4];
} index_object;

typedef struct pack_index {
    uint32_t magic_number;
    uint32_t nbo_version;
    uint32_t nbo_fanout[256];
    index_object first_index_object;
} pack_index;

@interface DiskPackIndex (internal)
- (BOOL)savePackIndex:(ServerBlob *)sb error:(NSError **)error;
- (PackIndexEntry *)doEntryForSHA1:(NSString *)sha1 error:(NSError **)error;
- (PackIndexEntry *)findEntryForSHA1:(NSString *)sha1 fd:(int)fd betweenStartIndex:(uint32_t)startIndex andEndIndex:(uint32_t)endIndex error:(NSError **)error;
- (BOOL)readFanoutStartIndex:(uint32_t *)start fanoutEndIndex:(uint32_t *)end fromFD:(int)fd forSHA1FirstByte:(unsigned int)firstByte error:(NSError **)error;
@end

@implementation DiskPackIndex
+ (NSString *)s3PathWithS3BucketName:(NSString *)theS3BucketName computerUUID:(NSString *)theComputerUUID packSetName:(NSString *)thePackSetName packSHA1:(NSString *)thePackSHA1 {
    return [NSString stringWithFormat:@"/%@/%@/packsets/%@/%@.index", theS3BucketName, theComputerUUID, thePackSetName, thePackSHA1];
}
+ (NSString *)localPathWithS3BucketName:theS3BucketName computerUUID:(NSString *)theComputerUUID packSetName:(NSString *)thePackSetName packSHA1:(NSString *)thePackSHA1 {
    return [NSString stringWithFormat:@"%@/%@/%@/packsets/%@/%@/%@.index", [UserLibrary arqCachePath], theS3BucketName, theComputerUUID, thePackSetName, [thePackSHA1 substringToIndex:2], [thePackSHA1 substringFromIndex:2]];
}
+ (NSArray *)diskPackIndexesForS3Service:(S3Service *)theS3
                            s3BucketName:theS3BucketName 
                            computerUUID:(NSString *)theComputerUUID 
                             packSetName:(NSString *)thePackSetName 
                               targetUID:(uid_t)theTargetUID 
                               targetGID:(gid_t)theTargetGID
                                   error:(NSError **)error {
    NSMutableArray *diskPackIndexes = [NSMutableArray array];
    NSString *packSetsPrefix = [NSString stringWithFormat:@"/%@/%@/packsets/%@/", theS3BucketName, theComputerUUID, thePackSetName];
    NSArray *paths = [theS3 pathsWithPrefix:packSetsPrefix error:error];
    if (paths == nil) {
        return nil;
    }
    for (NSString *thePath in paths) {
        NSRange sha1Range = [thePath rangeOfRegex:@"/(\\w+)\\.pack$" capture:1];
        if (sha1Range.location != NSNotFound) {
            NSString *thePackSHA1 = [thePath substringWithRange:sha1Range];
            DiskPackIndex *index = [[DiskPackIndex alloc] initWithS3Service:theS3 
                                                               s3BucketName:theS3BucketName
                                                               computerUUID:theComputerUUID 
                                                                packSetName:thePackSetName 
                                                                   packSHA1:thePackSHA1 
                                                                  targetUID:theTargetUID 
                                                                  targetGID:theTargetGID];
            [diskPackIndexes addObject:index];
            [index release];
        }            
    }
    return diskPackIndexes;
}


- (id)initWithS3Service:(S3Service *)theS3 
           s3BucketName:(NSString *)theS3BucketName 
           computerUUID:(NSString *)theComputerUUID 
            packSetName:(NSString *)thePackSetName 
               packSHA1:(NSString *)thePackSHA1
              targetUID:(uid_t)theTargetUID 
              targetGID:(gid_t)theTargetGID {
    if (self = [super init]) {
        s3 = [theS3 retain];
        s3BucketName = [theS3BucketName retain];
        computerUUID = [theComputerUUID retain];
        packSetName = [thePackSetName retain];
        packSHA1 = [thePackSHA1 retain];
        s3Path = [[DiskPackIndex s3PathWithS3BucketName:s3BucketName computerUUID:computerUUID packSetName:packSetName packSHA1:packSHA1] retain];
        localPath = [[DiskPackIndex localPathWithS3BucketName:s3BucketName computerUUID:computerUUID packSetName:packSetName packSHA1:packSHA1] retain];
        targetUID = theTargetUID;
        targetGID = theTargetGID;
    }
    return self;
}
- (void)dealloc {
    [s3 release];
    [s3BucketName release];
    [computerUUID release];
    [packSetName release];
    [packSHA1 release];
    [s3Path release];
    [localPath release];
    [super dealloc];
}
- (BOOL)makeLocal:(NSError **)error {
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL ret = YES;
    if (![fm fileExistsAtPath:localPath]) {
        for (;;) {
            HSLogDebug(@"packset %@: making pack index %@ local", packSetName, packSHA1);
            NSError *myError = nil;
            ServerBlob *sb = [s3 newServerBlobAtPath:s3Path error:&myError];
            if (sb != nil) {
                ret = [self savePackIndex:sb error:error];
                [sb release];
                break;
            }
            if (![myError isTransientError]) {
                HSLogError(@"error getting S3 pack index %@: %@", s3Path, myError);
                if (error != NULL) {
                    *error = myError;
                }
                ret = NO;
                break;
            }
            HSLogWarn(@"network error making pack index %@ local (retrying): %@", s3Path, myError);
            NSError *rmError = nil;
            if (![[NSFileManager defaultManager] removeItemAtPath:localPath error:&rmError]) {
                HSLogError(@"error deleting incomplete downloaded pack index %@: %@", localPath, rmError);
            }
        }
    }
    return ret;
}
- (NSArray *)allPackIndexEntries:(NSError **)error {
    int fd = open([localPath fileSystemRepresentation], O_RDONLY);
    if (fd == -1) {
        int errnum = errno;
        HSLogError(@"open(%@) error %d: %s", localPath, errnum, strerror(errnum));
        SETNSERROR(@"UnixErrorDomain", errnum, @"failed to open %@: %s", localPath, strerror(errnum));
        return nil;
    }
    struct stat st;
    if (fstat(fd, &st) == -1) {
        int errnum = errno;
        HSLogError(@"fstat(%@) error %d: %s", localPath, errnum, strerror(errnum));
        SETNSERROR(@"UnixErrorDomain", errnum, @"%@: %s", localPath, strerror(errnum));
        close(fd);
        return nil;
    }
    pack_index *the_pack_index = mmap(0, st.st_size, PROT_READ, MAP_SHARED, fd, 0);
    if (the_pack_index == MAP_FAILED) {
        int errnum = errno;
        HSLogError(@"mmap(%@) error %d: %s", localPath, errnum, strerror(errnum));
        SETNSERROR(@"UnixErrorDomain", errnum, @"error mapping %@ to memory: %s", localPath, strerror(errnum));
        close(fd);
        return NO;
    }
    NSMutableArray *ret = [NSMutableArray array];
    uint32_t count = OSSwapBigToHostInt32(the_pack_index->nbo_fanout[255]);
    index_object *indexObjects = &(the_pack_index->first_index_object);
    for (uint32_t i = 0; i < count; i++) {
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        uint64_t offset = OSSwapBigToHostInt64(indexObjects[i].nbo_offset);
        uint64_t dataLength = OSSwapBigToHostInt64(indexObjects[i].nbo_datalength);
        NSString *objectSHA1 = [NSString hexStringWithBytes:indexObjects[i].sha1 length:20];
        PackIndexEntry *pie = [[[PackIndexEntry alloc] initWithPackSHA1:packSHA1 offset:offset dataLength:dataLength objectSHA1:objectSHA1] autorelease];
        [ret addObject:pie];
        [pool drain];
    }
    if (munmap(the_pack_index, st.st_size) == -1) {
        int errnum = errno;
        HSLogError(@"munmap: %s", strerror(errnum));
    }
    close(fd);
    return ret;
}
- (PackIndexEntry *)entryForSHA1:(NSString *)sha1 error:(NSError **)error {
    if (error != NULL) {
        *error = nil;
    }
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    PackIndexEntry *ret = [self doEntryForSHA1:sha1 error:error];
    [ret retain];
    if (ret == nil && error != NULL) {
        [*error retain];
    }
    [pool drain];
    [ret autorelease];
    if (ret == nil && error != NULL) {
        [*error autorelease];
    }
    return ret;
}
- (NSString *)packSetName {
    return packSetName;
}
- (NSString *)packSHA1 {
    return packSHA1;
}

#pragma mark NSObject
- (NSString *)description {
    return [NSString stringWithFormat:@"<DiskPackIndex: computerUUID=%@ packset=%@ packSHA1=%@>", computerUUID, packSetName, packSHA1];
}
@end

@implementation DiskPackIndex (internal)
- (BOOL)savePackIndex:(ServerBlob *)sb error:(NSError **)error {
    if (![[NSFileManager defaultManager] ensureParentPathExistsForPath:localPath targetUID:targetUID targetGID:targetGID error:error]) {
        return NO;
    }
    id <InputStream> is = [sb newInputStream];
    NSError *myError = nil;
    unsigned long long written = 0;
    BOOL ret = [Streams transferFrom:is atomicallyToFile:localPath targetUID:targetUID targetGID:targetGID bytesWritten:&written error:&myError];
    if (ret) {
        HSLogDebug(@"wrote %qu bytes to %@", written, localPath);
    } else {
        if (error != NULL) {
            *error = myError;
        }
        HSLogError(@"error making pack %@ local at %@: %@", packSHA1, localPath, [myError localizedDescription]);
    }
    [is release];
    return ret;
}
- (PackIndexEntry *)doEntryForSHA1:(NSString *)sha1 error:(NSError **)error {
    NSData *sha1Hex = [sha1 hexStringToData];
    unsigned char *sha1Bytes = (unsigned char *)[sha1Hex bytes];
    HSLogTrace(@"looking for sha1 %@ in packindex %@", sha1, packSHA1);
    int fd = open([localPath fileSystemRepresentation], O_RDONLY);
    if (fd == -1) {
        int errnum = errno;
        HSLogError(@"open(%@) error %d: %s", localPath, errnum, strerror(errnum));
        SETNSERROR(@"UnixErrorDomain", errnum, @"failed to open %@: %s", localPath, strerror(errnum));
        return nil;
    }
    uint32_t startIndex;
    uint32_t endIndex;
    if (![self readFanoutStartIndex:&startIndex fanoutEndIndex:&endIndex fromFD:fd forSHA1FirstByte:(unsigned int)sha1Bytes[0] error:error]) {
        close(fd);
        return nil;
    }
    close(fd);
    if (endIndex == 0) {
        SETNSERROR(@"PacksErrorDomain", ERROR_NOT_FOUND, @"sha1 %@ not found in pack", sha1);
        return NO;
    }
    fd = open([localPath fileSystemRepresentation], O_RDONLY);
    if (fd == -1) {
        int errnum = errno;
        HSLogError(@"open(%@) error %d: %s", localPath, errnum, strerror(errnum));
        SETNSERROR(@"UnixErrorDomain", errnum, @"failed to open %@: %s", localPath, strerror(errnum));
        return nil;
    }
    PackIndexEntry *ret = [self findEntryForSHA1:sha1 fd:fd betweenStartIndex:startIndex andEndIndex:endIndex error:error];
    close(fd);
    if (ret != nil) {
        HSLogTrace(@"found sha1 %@ in packindex %@", sha1, packSHA1);
    }
    return ret;
}
- (PackIndexEntry *)findEntryForSHA1:(NSString *)sha1 fd:(int)fd betweenStartIndex:(uint32_t)startIndex andEndIndex:(uint32_t)endIndex error:(NSError **)error {
    NSData *sha1Data = [sha1 hexStringToData];
    const void *sha1Bytes = [sha1Data bytes];
    uint32_t lengthToMap = 4 + 4 + 256*4 + endIndex * sizeof(index_object);
    pack_index *the_pack_index = mmap(0, lengthToMap, PROT_READ, MAP_SHARED, fd, 0);
    if (the_pack_index == MAP_FAILED) {
        int errnum = errno;
        HSLogError(@"mmap(%@) error %d: %s", localPath, errnum, strerror(errnum));
        SETNSERROR(@"UnixErrorDomain", errnum, @"error mapping %@ to memory: %s", localPath, strerror(errnum));
        return NO;
    }
    int64_t left = startIndex;
    int64_t right = endIndex - 1;
    int64_t middle;
    int64_t offset;
    int64_t dataLength;
    PackIndexEntry *pie = nil;
    while (left <= right) {
        middle = (left + right)/2;
        index_object *firstIndexObject = &(the_pack_index->first_index_object);
        index_object *middleIndexObject = &firstIndexObject[middle];
        void *middleSHA1 = middleIndexObject->sha1;
        NSComparisonResult result = [BinarySHA1 compare:middleSHA1 to:sha1Bytes];
        switch (result) {
            case NSOrderedAscending:
                left = middle + 1;
                break;
            case NSOrderedDescending:
                right = middle - 1;
                break;
            default:
                offset = OSSwapBigToHostInt64(middleIndexObject->nbo_offset);
                dataLength = OSSwapBigToHostInt64(middleIndexObject->nbo_datalength);
                pie = [[[PackIndexEntry alloc] initWithPackSHA1:packSHA1 offset:offset dataLength:dataLength objectSHA1:sha1] autorelease];
        }
        if (pie != nil) {
            break;
        }
    }
    if (munmap(the_pack_index, lengthToMap) == -1) {
        int errnum = errno;
        HSLogError(@"munmap: %s", strerror(errnum));
    }
    if (pie == nil) {
        SETNSERROR(@"PackErrorDomain", ERROR_NOT_FOUND, @"sha1 %@ not found in pack %@", sha1, packSHA1);
    }
    return pie;
}
- (BOOL)readFanoutStartIndex:(uint32_t *)start fanoutEndIndex:(uint32_t *)end fromFD:(int)fd forSHA1FirstByte:(unsigned int)firstByte error:(NSError **)error {
    size_t len = 4 + 4 + 4*256;
    uint32_t *map = mmap(0, len, PROT_READ, MAP_SHARED, fd, 0);
    if (map == MAP_FAILED) {
        int errnum = errno;
        HSLogError(@"mmap(%@) error %d: %s", localPath, errnum, strerror(errnum));
        SETNSERROR(@"UnixErrorDomain", errnum, @"error mapping %@ to memory: %s", localPath, strerror(errnum));
        return NO;
    }
    BOOL ret = YES;
    uint32_t magicNumber = OSSwapBigToHostInt32(map[0]);
    uint32_t version = OSSwapBigToHostInt32(map[1]);
    if (magicNumber != 0xff744f63 || version != 2) {
        SETNSERROR(@"PackErrorDomain", -1, @"invalid pack index header");
        ret = NO;
    } else {
        uint32_t *fanoutTable = map + 2;
        *start = 0;
        if (firstByte > 0) {
            *start = OSSwapBigToHostInt32(fanoutTable[firstByte - 1]);
        }
        *end = OSSwapBigToHostInt32(fanoutTable[firstByte]);
    }
    if (munmap(map, len) == -1) {
        int errnum = errno;
        HSLogError(@"munmap: %s", strerror(errnum));
    }
    return ret;
}
@end
