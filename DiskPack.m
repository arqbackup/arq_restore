//
//  DiskPack.m
//  Arq
//
//  Created by Stefan Reitshamer on 12/30/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#include <sys/stat.h>
#import "DiskPack.h"
#import "SetNSError.h"
#import "FDInputStream.h"
#import "StringIO.h"
#import "IntegerIO.h"
#import "ServerBlob.h"
#import "NSFileManager_extra.h"
#import "S3Service.h"
#import "ServerBlob.h"
#import "FileInputStream.h"
#import "FileOutputStream.h"
#import "Streams.h"
#import "S3ObjectReceiver.h"
#import "S3ObjectMetadata.h"
#import "PackIndexEntry.h"
#import "SHA1Hash.h"
#import "UserLibrary_Arq.h"
#import "BufferedInputStream.h"
#import "NSError_extra.h"


@interface DiskPack (internal)
- (BOOL)savePack:(ServerBlob *)sb error:(NSError **)error;
- (NSArray *)sortedPackIndexEntriesFromStream:(BufferedInputStream *)fis error:(NSError **)error;
@end

@implementation DiskPack
+ (NSString *)s3PathWithS3BucketName:(NSString *)theS3BucketName computerUUID:(NSString *)theComputerUUID packSetName:(NSString *)thePackSetName packSHA1:(NSString *)thePackSHA1 {
    return [NSString stringWithFormat:@"/%@/%@/packsets/%@/%@.pack", theS3BucketName, theComputerUUID, thePackSetName, thePackSHA1];
}
+ (NSString *)localPathWithS3BucketName:(NSString *)theS3BucketName computerUUID:(NSString *)theComputerUUID packSetName:(NSString *)thePackSetName packSHA1:(NSString *)thePackSHA1 {
    return [NSString stringWithFormat:@"%@/%@/%@/packsets/%@/%@/%@.pack", [UserLibrary arqCachePath], theS3BucketName, theComputerUUID, thePackSetName, [thePackSHA1 substringToIndex:2], [thePackSHA1 substringFromIndex:2]];
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
        s3Path = [[DiskPack s3PathWithS3BucketName:s3BucketName computerUUID:computerUUID packSetName:packSetName packSHA1:packSHA1] retain];
        localPath = [[DiskPack localPathWithS3BucketName:s3BucketName computerUUID:computerUUID packSetName:packSetName packSHA1:packSHA1] retain];
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
            HSLogDebug(@"packset %@: making pack %@ local", packSetName, packSHA1);
            NSError *myError = nil;
            ServerBlob *sb = [s3 newServerBlobAtPath:s3Path error:&myError];
            if (sb != nil) {
                ret = [self savePack:sb error:error];
                [sb release];
                break;
            }
            if (![myError isTransientError]) {
                HSLogError(@"error getting S3 pack %@: %@", s3Path, myError);
                if (error != NULL) {
                    *error = myError;
                }
                ret = NO;
                break;
            }
            HSLogWarn(@"network error making pack %@ local (retrying): %@", s3Path, myError);
            NSError *rmError = nil;
            if (![[NSFileManager defaultManager] removeItemAtPath:localPath error:&rmError]) {
                HSLogError(@"error deleting incomplete downloaded pack file %@: %@", localPath, rmError);
            }
        }
    }
    return ret;
}
- (BOOL)makeNotLocal:(NSError **)error {
    NSFileManager *fm = [NSFileManager defaultManager];
    HSLogDebug(@"removing disk pack %@", localPath);
    BOOL ret = YES;
    if ([fm fileExistsAtPath:localPath] && ![fm removeItemAtPath:localPath error:error]) {
        ret = NO;
    }
    return ret;
}
- (ServerBlob *)newServerBlobForObjectAtOffset:(unsigned long long)offset error:(NSError **)error {
    int fd = open([localPath fileSystemRepresentation], O_RDONLY);
    if (fd == -1) {
        int errnum = errno;
        HSLogError(@"open(%@) error %d: %s", localPath, errnum, strerror(errnum));
        SETNSERROR(@"UnixErrorDomain", errnum, @"failed to open %@: %s", localPath, strerror(errnum));
        return nil;
    }
    ServerBlob *ret = nil;
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
            unsigned char *buf = (unsigned char *)malloc(dataLen);
            if (![bis readExactly:dataLen into:buf error:error]) {
                free(buf);
                break;
            }
            data = [NSData dataWithBytesNoCopy:buf length:dataLen];
        } else {
            data = [NSData data];
        }
        ret = [[ServerBlob alloc] initWithData:data mimeType:mimeType downloadName:downloadName];
    } while (0);
    close(fd);
    [bis release];
    [fdis release];
    return ret;
}
- (BOOL)fileLength:(unsigned long long *)length error:(NSError **)error {
    struct stat st;
    if (lstat([localPath fileSystemRepresentation], &st) == -1) {
        int errnum = errno;
        HSLogError(@"lstat(%@) error %d: %s", localPath, errnum, strerror(errnum));
        SETNSERROR(@"UnixErrorDomain", errnum, @"%@: %s", localPath, strerror(errnum));
        return NO;
    }
    *length = st.st_size;
    return YES;
}
- (BOOL)copyToPath:(NSString *)dest error:(NSError **)error {
    NSFileManager *fm = [NSFileManager defaultManager];
    if ([fm fileExistsAtPath:dest] && ![fm removeItemAtPath:dest error:error]) {
        HSLogError(@"error removing old mutable pack at %@", dest);
        return NO;
    }
    if (![fm ensureParentPathExistsForPath:dest targetUID:targetUID targetGID:targetGID error:error] || ![fm copyItemAtPath:localPath toPath:dest error:error]) {
        HSLogError(@"error copying pack %@ to %@", localPath, dest);
        return NO;
    }
    if (chown([localPath fileSystemRepresentation], targetUID, targetGID) == -1) {
        int errnum = errno;
        SETNSERROR(@"UnixErrorDomain", errnum, @"chown(%@): %s", localPath, strerror(errnum));
        return NO;
    }
    HSLogDebug(@"copied %@ to %@", localPath, dest);
    return YES;
}
- (NSArray *)sortedPackIndexEntries:(NSError **)error {
    unsigned long long length;
    if (![self fileLength:&length error:error]) {
        return NO;
    }
    FileInputStream *fis = [[FileInputStream alloc] initWithPath:localPath offset:0 length:length];
    BufferedInputStream *bis = [[BufferedInputStream alloc] initWithUnderlyingStream:fis];
    NSArray *ret = [self sortedPackIndexEntriesFromStream:bis error:error];
    [bis release];
    [fis release];
    return ret;
}
@end

@implementation  DiskPack (internal)
- (BOOL)savePack:(ServerBlob *)sb error:(NSError **)error {
    if (![[NSFileManager defaultManager] ensureParentPathExistsForPath:localPath targetUID:targetUID targetGID:targetGID error:error]) {
        return NO;
    }
    id <InputStream> is = [sb newInputStream];
    NSError *myError;
    unsigned long long written;
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
- (NSArray *)sortedPackIndexEntriesFromStream:(BufferedInputStream *)is error:(NSError **)error {
    uint32_t packSig;
    uint32_t packVersion;
    if (![IntegerIO readUInt32:&packSig from:is error:error] || ![IntegerIO readUInt32:&packVersion from:is error:error]) {
        return nil;
    }
    if (packSig != 0x5041434b) { // "PACK"
        SETNSERROR(@"PackErrorDomain", -1, @"invalid pack signature");
        return nil;
    }
    if (packVersion != 2) {
        SETNSERROR(@"PackErrorDomain", -1, @"invalid pack version");
    }
    uint32_t objectCount;
    if (![IntegerIO readUInt32:&objectCount from:is error:error]) {
        return nil;
    }
    
    NSMutableArray *ret = [NSMutableArray array];
    for (uint32_t index = 0; index < objectCount; index++) {
        uint64_t offset = [is bytesReceived];
        NSString *mimeType;
        NSString *name;
        uint64_t length;
        if (![StringIO read:&mimeType from:is error:error] || ![StringIO read:&name from:is error:error] || ![IntegerIO readUInt64:&length from:is error:error]) {
            return NO;
        }
        NSString *objectSHA1 = [SHA1Hash hashStream:is withLength:length error:error];
        if (objectSHA1 == nil) {
            return NO;
        }
        PackIndexEntry *pie = [[PackIndexEntry alloc] initWithPackSHA1:packSHA1 offset:offset dataLength:length objectSHA1:objectSHA1];
        [ret addObject:pie];
        [pie release];
    }
    return ret;    
}

#pragma mark NSObject
- (NSString *)description {
    return [NSString stringWithFormat:@"<DiskPack s3Bucket=%@ computerUUID=%@ packset=%@ sha1=%@ localPath=%@>", s3BucketName, computerUUID, packSetName, packSHA1, localPath];
}
@end
