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


#import "GlacierPack.h"
#import "UserLibrary_Arq.h"
#import "NSFileManager_extra.h"
#import "FDInputStream.h"
#import "BufferedInputStream.h"
#import "StringIO.h"
#import "IntegerIO.h"
#import "Streams.h"
#import "Target.h"


@implementation GlacierPack
- (id)initWithTarget:(Target *)theTarget
        s3BucketName:(NSString *)theS3BucketName
        computerUUID:(NSString *)theComputerUUID
          bucketUUID:(NSString *)theBucketUUID
            packSHA1:(NSString *)thePackSHA1
           archiveId:(NSString *)theArchiveId
            packSize:(unsigned long long)thePackSize
           targetUID:(uid_t)theTargetUID
           targetGID:(gid_t)theTargetGID {
    if (self = [super init]) {
        s3BucketName = [theS3BucketName retain];
        computerUUID = [theComputerUUID retain];
        bucketUUID = [theBucketUUID retain];
        packSetName = [[NSString alloc] initWithFormat:@"%@-glacierblobs", theBucketUUID];
        packSHA1 = [thePackSHA1 retain];
        archiveId = [theArchiveId retain];
        packSize = thePackSize;
        uid = theTargetUID;
        gid = theTargetGID;
        localPath = [[NSString alloc] initWithFormat:@"%@/%@/%@/glacier_packsets/%@/%@/%@.pack",
                     [UserLibrary arqCachePath], [theTarget targetUUID], computerUUID, packSetName, [packSHA1 substringToIndex:2], [packSHA1 substringFromIndex:2]];
    }
    return self;
}
- (void)dealloc {
    [s3BucketName release];
    [computerUUID release];
    [bucketUUID release];
    [packSetName release];
    [packSHA1 release];
    [archiveId release];
    [localPath release];
    [super dealloc];
}

- (NSString *)packSHA1 {
    return packSHA1;
}
- (NSString *)archiveId {
    return archiveId;
}
- (unsigned long long)packSize {
    return packSize;
}
- (BOOL)cachePackDataToDisk:(NSData *)thePackData error:(NSError **)error {
    if (![[NSFileManager defaultManager] ensureParentPathExistsForPath:localPath targetUID:uid targetGID:gid error:error]) {
        return NO;
    }
    return [Streams writeData:thePackData atomicallyToFile:localPath targetUID:uid targetGID:gid bytesWritten:NULL error:error];
}
- (NSData *)cachedDataForObjectAtOffset:(unsigned long long)offset error:(NSError **)error {
    int fd = open([localPath fileSystemRepresentation], O_RDONLY);
    if (fd == -1) {
        int errnum = errno;
        HSLogError(@"open(%@) error %d: %s", localPath, errnum, strerror(errnum));
        SETNSERROR(@"UnixErrorDomain", errnum, @"failed to open %@: %s", localPath, strerror(errnum));
        return nil;
    }
    NSData *ret = nil;
    FDInputStream *fdis = [[FDInputStream alloc] initWithFD:fd label:localPath];
    BufferedInputStream *bis = [[BufferedInputStream alloc] initWithUnderlyingStream:fdis];
    do {
        if (lseek(fd, offset, SEEK_SET) == -1) {
            int errnum = errno;
            HSLogError(@"lseek(%@, %qu) error %d: %s", localPath, offset, errnum, strerror(errnum));
            SETNSERROR(@"UnixErrorDomain", errnum, @"failed to seek to %qu in %@: %s", offset, localPath, strerror(errnum));
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


#pragma mark NSObject
- (NSString *)description {
    return [NSString stringWithFormat:@"<GlacierPack packSHA1=%@>", packSHA1];
}
@end
