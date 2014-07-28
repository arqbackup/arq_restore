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


#include <sys/stat.h>
#include <sys/mman.h>
#include <libkern/OSByteOrder.h>
#import "GlacierPackIndex.h"
#import "S3Service.h"
#import "RegexKitLite.h"
#import "NSString_extra.h"
#import "BinarySHA1.h"
#import "PackIndexEntry.h"
#import "FileOutputStream.h"
#import "Streams.h"
#import "NSFileManager_extra.h"
#import "UserLibrary_Arq.h"
#import "NSError_extra.h"
#import "DataInputStream.h"
#import "FDInputStream.h"
#import "BufferedInputStream.h"
#import "StringIO.h"
#import "IntegerIO.h"
#import "PackId.h"
#import "Target.h"


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


@implementation GlacierPackIndex
+ (NSString *)s3PathWithS3BucketName:(NSString *)theS3BucketName computerUUID:(NSString *)theComputerUUID packId:(PackId *)thePackId {
    return [NSString stringWithFormat:@"/%@/%@/packsets/%@/%@.index", theS3BucketName, theComputerUUID, [thePackId packSetName], [thePackId packSHA1]];
}
+ (NSString *)localPathWithTarget:(Target *)theTarget computerUUID:(NSString *)theComputerUUID packId:(PackId *)thePackId {
    return [NSString stringWithFormat:@"%@/%@/%@/glacier_packsets/%@/%@/%@.index", [UserLibrary arqCachePath], [theTarget targetUUID], theComputerUUID, [thePackId packSetName], [[thePackId packSHA1] substringToIndex:2], [[thePackId packSHA1] substringFromIndex:2]];
}
+ (NSArray *)glacierPackIndexesForTarget:(Target *)theTarget
                               s3Service:(S3Service *)theS3
                            s3BucketName:theS3BucketName
                            computerUUID:(NSString *)theComputerUUID
                             packSetName:(NSString *)thePackSetName
                targetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD
                               targetUID:(uid_t)theTargetUID
                               targetGID:(gid_t)theTargetGID
                                   error:(NSError **)error {
    NSMutableArray *diskPackIndexes = [NSMutableArray array];
    NSString *packSetsPrefix = [NSString stringWithFormat:@"/%@/%@/packsets/%@/", theS3BucketName, theComputerUUID, thePackSetName];
    NSArray *paths = [theS3 pathsWithPrefix:packSetsPrefix targetConnectionDelegate:theTCD error:error];
    if (paths == nil) {
        return nil;
    }
    for (NSString *thePath in paths) {
        NSRange sha1Range = [thePath rangeOfRegex:@"/(\\w+)\\.index$" capture:1];
        if (sha1Range.location != NSNotFound) {
            NSString *thePackSHA1 = [thePath substringWithRange:sha1Range];
            PackId *packId = [[[PackId alloc] initWithPackSetName:thePackSetName packSHA1:thePackSHA1] autorelease];
            GlacierPackIndex *index = [[GlacierPackIndex alloc] initWithTarget:theTarget
                                                                     s3Service:theS3
                                                                  s3BucketName:theS3BucketName
                                                                  computerUUID:theComputerUUID
                                                                        packId:packId
                                                                     targetUID:theTargetUID
                                                                     targetGID:theTargetGID];
            [diskPackIndexes addObject:index];
            [index release];
        }
    }
    return diskPackIndexes;
}


- (id)initWithTarget:(Target *)theTarget
           s3Service:(S3Service *)theS3
        s3BucketName:(NSString *)theS3BucketName
        computerUUID:(NSString *)theComputerUUID
              packId:(PackId *)thePackId
           targetUID:(uid_t)theTargetUID
           targetGID:(gid_t)theTargetGID {
    if (self = [super init]) {
        s3 = [theS3 retain];
        s3BucketName = [theS3BucketName retain];
        computerUUID = [theComputerUUID retain];
        packId = [thePackId retain];
        s3Path = [[GlacierPackIndex s3PathWithS3BucketName:s3BucketName computerUUID:computerUUID packId:packId] retain];
        localPath = [[GlacierPackIndex localPathWithTarget:theTarget computerUUID:computerUUID packId:packId] retain];
        targetUID = theTargetUID;
        targetGID = theTargetGID;
    }
    return self;
}
- (void)dealloc {
    [s3 release];
    [s3BucketName release];
    [computerUUID release];
    [packId release];
    [s3Path release];
    [localPath release];
    [pies release];
    [archiveId release];
    [super dealloc];
}
- (BOOL)makeLocalWithTargetConnectionDelegate:(id)theTCD error:(NSError **)error {
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL ret = YES;
    if (![fm fileExistsAtPath:localPath]) {
        for (;;) {
            HSLogDebug(@"packset %@: making pack index %@ local", packId, packId);
            NSError *myError = nil;
            NSData *data = [s3 dataAtPath:s3Path targetConnectionDelegate:theTCD error:&myError];
            if (data != nil) {
                ret = [self savePackIndex:data error:error];
                break;
            }
            if (![myError isTransientError]) {
                HSLogError(@"error getting S3 pack index %@: %@", s3Path, myError);
                if (error != NULL) {
                    *error = myError;
                }
                ret = NO;
                break;
            } else {
                HSLogWarn(@"network error making pack index %@ local (retrying): %@", s3Path, myError);
                NSError *rmError = nil;
                if ([[NSFileManager defaultManager] fileExistsAtPath:localPath] && ![[NSFileManager defaultManager] removeItemAtPath:localPath error:&rmError]) {
                    HSLogError(@"error deleting incomplete downloaded pack index %@: %@", localPath, rmError);
                }
            }
        }
    }
    return ret;
}
- (NSArray *)allPackIndexEntriesWithTargetConnectionDelegate:(id<TargetConnectionDelegate>)theTCD error:(NSError **)error {
    if (![self makeLocalWithTargetConnectionDelegate:theTCD error:error]) {
        return nil;
    }
    if (![self readFile:error]) {
        return nil;
    }
    return pies;
}

- (PackIndexEntry *)entryForSHA1:(NSString *)sha1 error:(NSError **)error {
    if (error != NULL) {
        *error = nil;
    }
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    PackIndexEntry *ret = [self doEntryForSHA1:sha1 error:(NSError **)error];
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
- (PackId *)packId {
    return packId;
}
- (NSString *)archiveId:(NSError **)error {
    if (![self readFile:error]) {
        return nil;
    }
    return archiveId;
}
- (unsigned long long)packSize:(NSError **)error {
    if (![self readFile:error]) {
        return 0;
    }
    return packSize;
}


#pragma mark NSObject
- (NSString *)description {
    return [NSString stringWithFormat:@"<DiskPackIndex: computerUUID=%@ packId=%@>", computerUUID, packId];
}


#pragma mark internal
- (BOOL)readFile:(NSError **)error {
    if (pies != nil) {
        return YES;
    }
    
    int fd = open([localPath fileSystemRepresentation], O_RDONLY);
    if (fd == -1) {
        int errnum = errno;
        HSLogError(@"open(%@) error %d: %s", localPath, errnum, strerror(errnum));
        SETNSERROR(@"UnixErrorDomain", errnum, @"failed to open %@: %s", localPath, strerror(errnum));
        return NO;
    }
    struct stat st;
    if (fstat(fd, &st) == -1) {
        int errnum = errno;
        HSLogError(@"fstat(%@) error %d: %s", localPath, errnum, strerror(errnum));
        SETNSERROR(@"UnixErrorDomain", errnum, @"%@: %s", localPath, strerror(errnum));
        close(fd);
        return NO;
    }
    if (st.st_size < sizeof(pack_index)) {
        HSLogError(@"pack index length %ld is less than size of pack_index", (unsigned long)st.st_size);
        SETNSERROR(@"GlacierPackIndexErrorDomain", -1, @"pack index length is less than size of pack_index");
        close(fd);
        return NO;
    }
    pack_index *the_pack_index = mmap(0, (size_t)st.st_size, PROT_READ, MAP_SHARED, fd, 0);
    if (the_pack_index == MAP_FAILED) {
        int errnum = errno;
        HSLogError(@"mmap(%@) error %d: %s", localPath, errnum, strerror(errnum));
        SETNSERROR(@"UnixErrorDomain", errnum, @"error mapping %@ to memory: %s", localPath, strerror(errnum));
        close(fd);
        return NO;
    }
    pies = [[NSMutableArray alloc] init];
    uint32_t count = OSSwapBigToHostInt32(the_pack_index->nbo_fanout[255]);
    index_object *indexObjects = &(the_pack_index->first_index_object);
    for (uint32_t i = 0; i < count; i++) {
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        uint64_t offset = OSSwapBigToHostInt64(indexObjects[i].nbo_offset);
        uint64_t dataLength = OSSwapBigToHostInt64(indexObjects[i].nbo_datalength);
        NSString *objectSHA1 = [NSString hexStringWithBytes:indexObjects[i].sha1 length:20];
        PackIndexEntry *pie = [[[PackIndexEntry alloc] initWithPackId:packId offset:offset dataLength:dataLength objectSHA1:objectSHA1] autorelease];
        [pies addObject:pie];
        [pool drain];
    }
    if (munmap(the_pack_index, (size_t)st.st_size) == -1) {
        int errnum = errno;
        HSLogError(@"munmap: %s", strerror(errnum));
    }
    
    uint32_t offset = sizeof(pack_index) + (count - 1) * sizeof(index_object);
    if (!lseek(fd, offset, SEEK_SET) == -1) {
        int errnum = errno;
        HSLogError(@"lstat(%@, %ld) error %d: %s", localPath, (unsigned long)offset, errnum, strerror(errnum));
        SETNSERROR(@"UnixErrorDomain", errnum, @"error seeking to archiveId in pack index file");
        close(fd);
        return NO;
    }
    FDInputStream *fdis = [[[FDInputStream alloc] initWithFD:fd label:@"packindex"] autorelease];
    BufferedInputStream *bis = [[[BufferedInputStream alloc] initWithUnderlyingStream:fdis] autorelease];
    BOOL ret = [StringIO read:&archiveId from:bis error:error] && [IntegerIO readUInt64:&packSize from:bis error:error];
    [archiveId retain];
    close(fd);
    if (!ret) {
        return NO;
    }
    return YES;
}
- (BOOL)savePackIndex:(NSData *)theData error:(NSError **)error {
    if (![[NSFileManager defaultManager] ensureParentPathExistsForPath:localPath targetUID:targetUID targetGID:targetGID error:error]) {
        return NO;
    }
    id <InputStream> is = [[[DataInputStream alloc] initWithData:theData description:[self description]] autorelease];
    NSError *myError = nil;
    unsigned long long written = 0;
    BOOL ret = [Streams transferFrom:is atomicallyToFile:localPath targetUID:targetUID targetGID:targetGID bytesWritten:&written error:&myError];
    if (ret) {
        HSLogDebug(@"wrote %qu bytes to %@", written, localPath);
    } else {
        if (error != NULL) {
            *error = myError;
        }
        HSLogError(@"error making pack %@ local at %@: %@", packId, localPath, [myError localizedDescription]);
    }
    return ret;
}
- (PackIndexEntry *)doEntryForSHA1:(NSString *)sha1 error:(NSError **)error {
    NSData *sha1Hex = [sha1 hexStringToData:error];
    if (sha1Hex == nil) {
        return nil;
    }
    unsigned char *sha1Bytes = (unsigned char *)[sha1Hex bytes];
    HSLogTrace(@"looking for sha1 %@ in packindex %@", sha1, packId);
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
        HSLogTrace(@"found sha1 %@ in packindex %@", sha1, packId);
    }
    return ret;
}
- (PackIndexEntry *)findEntryForSHA1:(NSString *)sha1 fd:(int)fd betweenStartIndex:(uint32_t)startIndex andEndIndex:(uint32_t)endIndex error:(NSError **)error {
    NSData *sha1Data = [sha1 hexStringToData:error];
    if (sha1Data == nil) {
        return nil;
    }
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
                pie = [[[PackIndexEntry alloc] initWithPackId:packId offset:offset dataLength:dataLength objectSHA1:sha1] autorelease];
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
        SETNSERROR(@"PackErrorDomain", ERROR_NOT_FOUND, @"sha1 %@ not found in pack %@", sha1, packId);
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
