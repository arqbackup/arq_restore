/*
 Copyright (c) 2009, Stefan Reitshamer http://www.haystacksoftware.com
 
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
#import "DiskPack.h"
#import "SetNSError.h"
#import "FDInputStream.h"
#import "BufferedInputStream.h"
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
#import "ArqUserLibrary.h"

@interface DiskPack (internal)
- (BOOL)savePack:(ServerBlob *)sb bytesWritten:(unsigned long long *)written error:(NSError **)error;
- (NSArray *)sortedPackIndexEntriesFromStream:(BufferedInputStream *)fis error:(NSError **)error;
@end

@implementation DiskPack
+ (NSString *)s3PathWithS3BucketName:(NSString *)theS3BucketName computerUUID:(NSString *)theComputerUUID packSetName:(NSString *)thePackSetName packSHA1:(NSString *)thePackSHA1 {
    return [NSString stringWithFormat:@"/%@/%@/packsets/%@/%@.pack", theS3BucketName, theComputerUUID, thePackSetName, thePackSHA1];
}
+ (NSString *)localPathWithComputerUUID:(NSString *)theComputerUUID packSetName:(NSString *)thePackSetName packSHA1:(NSString *)thePackSHA1 {
    return [NSString stringWithFormat:@"%@/%@/packsets/%@/%@/%@.pack", [ArqUserLibrary arqCachesPath], theComputerUUID, thePackSetName, [thePackSHA1 substringToIndex:2], [thePackSHA1 substringFromIndex:2]];
}
- (id)initWithS3Service:(S3Service *)theS3 s3BucketName:(NSString *)theS3BucketName computerUUID:(NSString *)theComputerUUID packSetName:(NSString *)thePackSetName packSHA1:(NSString *)thePackSHA1 {
    if (self = [super init]) {
        s3 = [theS3 retain];
        s3BucketName = [theS3BucketName retain];
        computerUUID = [theComputerUUID retain];
        packSetName = [thePackSetName retain];
        packSHA1 = [thePackSHA1 retain];
        s3Path = [[DiskPack s3PathWithS3BucketName:s3BucketName computerUUID:computerUUID packSetName:packSetName packSHA1:packSHA1] retain];
        localPath = [[DiskPack localPathWithComputerUUID:computerUUID packSetName:packSetName packSHA1:packSHA1] retain];
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
    BOOL ret = NO;
    if (![fm fileExistsAtPath:localPath]) {
        HSLogDebug(@"packset %@: making pack %@ local", packSetName, packSHA1);
        NSError *myError = nil;
        ServerBlob *sb = [s3 newServerBlobAtPath:s3Path error:&myError];
        if (sb == nil) {
            HSLogError(@"error getting S3 pack %@: %@", s3Path, [myError localizedDescription]);
            if (error != NULL) {
                *error = myError;
            }
        } else {
            unsigned long long bytesWritten;
            ret = [self savePack:sb bytesWritten:&bytesWritten error:error];
            [sb release];
        }
    } else {
        ret = YES;
    }
    return ret;
}
- (ServerBlob *)newServerBlobForObjectAtOffset:(unsigned long long)offset error:(NSError **)error {
    int fd = open([localPath fileSystemRepresentation], O_RDONLY);
    if (fd == -1) {
        SETNSERROR(@"UnixErrorDomain", errno, @"%s: %@", strerror(errno), localPath);
        return nil;
    }
    ServerBlob *ret = nil;
    FDInputStream *fdis = [[FDInputStream alloc] initWithFD:fd];
    BufferedInputStream *bis = [[BufferedInputStream alloc] initWithUnderlyingStream:fdis];
    do {
        if (lseek(fd, offset, SEEK_SET) == -1) {
            SETNSERROR(@"UnixErrorDomain", errno, @"lseek(%@, %qu): %s", localPath, offset, strerror(errno));
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
            data = [bis readExactly:dataLen error:error];
            if (data == nil) {
                break;
            }
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
        SETNSERROR(@"UnixErrorDomain", errno, @"lstat(%@): %s", localPath, strerror(errno));
        return NO;
    }
    *length = st.st_size;
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
- (BOOL)savePack:(ServerBlob *)sb bytesWritten:(unsigned long long *)written error:(NSError **)error {
    if (![[NSFileManager defaultManager] ensureParentPathExistsForPath:localPath error:error]) {
        return NO;
    }
    id <InputStream> is = [sb newInputStream];
    NSError *myError;
    BOOL ret = [Streams transferFrom:is atomicallyToFile:localPath bytesWritten:written error:&myError];
    if (ret) {
        HSLogDebug(@"wrote %qu bytes to %@", *written, localPath);
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
@end
