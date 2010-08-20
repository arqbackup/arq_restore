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

#include <sys/types.h>
#include <sys/stat.h>
#import "Restorer.h"
#import "ArqFark.h"
#import "ArqRepo.h"
#import "SetNSError.h"
#import "Tree.h"
#import "Node.h"
#import "RestoreNode.h"
#import "FileAttributes.h"
#import "NSData-InputStream.h"
#import "DataInputStream.h"
#import "XAttrSet.h"
#import "FileOutputStream.h"
#import "NSFileManager_extra.h"
#import "CFStreamPair.h"
#import "NSErrorCodes.h"
#import "BufferedInputStream.h"
#import "StreamPairFactory.h"

#define MAX_RETRIES (10)
#define MY_BUF_SIZE (8192)

@interface Restorer (internal)
- (BOOL)addRestoreNodesForTreeSHA1:(NSString *)treeSHA1 relativePath:(NSString *)relativePath error:(NSError **)error;
- (BOOL)restoreRestoreNode:(RestoreNode *)rn error:(NSError **)error;
- (BOOL)createFile:(Node *)node atPath:(NSString *)path error:(NSError **)error;
- (BOOL)createFileAtPath:(NSString *)path fromSHA1s:(NSArray *)dataSHA1s error:(NSError **)error;
- (BOOL)appendBlobForSHA1:(NSString *)sha1 toFile:(FileOutputStream *)fos error:(NSError **)error;
- (BOOL)doAppendBlobForSHA1:(NSString *)sha1 toFile:(FileOutputStream *)fos error:(NSError **)error;
- (BOOL)applyTree:(Tree *)tree toPath:(NSString *)restorePath error:(NSError **)error;
- (BOOL)applyNode:(Node *)node toPath:(NSString *)restorePath error:(NSError **)error;
- (BOOL)applyACLSHA1:(NSString *)aclSHA1 toFileAttributes:(FileAttributes *)fa error:(NSError **)error;
- (BOOL)applyXAttrsSHA1:(NSString *)xattrsSHA1 toFile:(NSString *)path error:(NSError **)error;
- (BOOL)createSymLink:(Node *)node path:(NSString *)symLinkFile target:(NSString *)target error:(NSError **)error;
@end

@implementation Restorer
- (id)initWithS3Service:(S3Service *)theS3 s3BucketName:(NSString *)theS3BucketName computerUUID:(NSString *)theComputerUUID bucketUUID:(NSString *)theBucketUUID bucketName:(NSString *)theBucketName encryptionKey:(NSString *)theEncryptionKey {
    if (self = [super init]) {
        fark = [[ArqFark alloc] initWithS3Service:theS3 s3BucketName:theS3BucketName computerUUID:theComputerUUID];
        repo = [[ArqRepo alloc] initWithS3Service:theS3 s3BucketName:theS3BucketName computerUUID:theComputerUUID bucketUUID:theBucketUUID encryptionKey:theEncryptionKey];
        bucketName = [theBucketName copy];
        rootPath = [[[[NSFileManager defaultManager] currentDirectoryPath] stringByAppendingPathComponent:theBucketName] copy];
        restoreNodes = [[NSMutableArray alloc] init];
        hardlinks = [[NSMutableDictionary alloc] init];
    }
    return self;
}
- (void)dealloc {
    [fark release];
    [repo release];
    [bucketName release];
    [rootPath release];
    [restoreNodes release];
    [hardlinks release];
    [super dealloc];
}
- (BOOL)restore:(NSError **)error {
    if ([[NSFileManager defaultManager] fileExistsAtPath:rootPath]) {
        SETNSERROR(@"RestorerErrorDomain", -1, @"%@ already exists", rootPath);
        return NO;
    }
    if (![[NSFileManager defaultManager] createDirectoryAtPath:rootPath withIntermediateDirectories:YES attributes:nil error:error]) {
        HSLogError(@"failed to create directory %@", rootPath);
        return NO;
    }
    NSString *headSHA1 = [repo headSHA1:error];
    if (headSHA1 == nil) {
        return NO;
    }
    if (headSHA1 == nil) {
        SETNSERROR(@"RestorerErrorDomain", -1, @"no backup found");
        return NO;
    }
    Commit *head = [repo commitForSHA1:headSHA1 error:error];
    if (head == nil) {
        return NO;
    }
    if (![self addRestoreNodesForTreeSHA1:[head treeSHA1] relativePath:@"" error:error]) {
        return NO;
    }
    for (RestoreNode *rn in restoreNodes) {
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *myError = nil;
        BOOL ret = [self restoreRestoreNode:rn error:&myError];
        [myError retain];
        [pool drain];
        [myError autorelease];
        if (!ret) {
            if (error != NULL) {
                *error = myError;
            }
            return NO;
        }
    }
    return YES;
}
@end

@implementation Restorer (internal)
- (BOOL)addRestoreNodesForTreeSHA1:(NSString *)treeSHA1 relativePath:(NSString *)relativePath error:(NSError **)error {
    Tree *tree = [repo treeForSHA1:treeSHA1 error:error];
    if (tree == nil) {
        return NO;
    }
    RestoreNode *treeRN = [[RestoreNode alloc] initWithTree:tree nodeName:nil relativePath:relativePath];
    [restoreNodes addObject:treeRN];
    [treeRN release];
    for (NSString *childNodeName in [tree childNodeNames]) {
        Node *childNode = [tree childNodeWithName:childNodeName];
        NSString *childRelativePath = [NSString stringWithFormat:@"%@/%@", relativePath, childNodeName];
        if ([childNode isTree]) {
            if (![self addRestoreNodesForTreeSHA1:[childNode treeSHA1] relativePath:childRelativePath error:error]) {
                return NO;
            }
        } else {
            RestoreNode *childRN = [[RestoreNode alloc] initWithTree:tree nodeName:childNodeName relativePath:childRelativePath];
            [restoreNodes addObject:childRN];
            [childRN release];
        }
    }
    return YES;
}
- (BOOL)restoreRestoreNode:(RestoreNode *)rn error:(NSError **)error {
    printf("restoring %s%s\n", [bucketName UTF8String], [[rn relativePath] UTF8String]);
    NSString *restorePath = [rootPath stringByAppendingPathComponent:[rn relativePath]];
    NSString *parentPath = [restorePath stringByDeletingLastPathComponent];
    if (![[NSFileManager defaultManager] fileExistsAtPath:parentPath] 
        && ![[NSFileManager defaultManager] createDirectoryAtPath:parentPath withIntermediateDirectories:YES attributes:nil error:error]) {
        HSLogError(@"failed to create directory %@", parentPath);
        return NO;
    }
    BOOL createdFile = NO;
    int nlink = [rn node] == nil ? [[rn tree] st_nlink] : [[rn node] st_nlink];
    if (nlink > 1) {
        int ino = [rn node] == nil ? [[rn tree] st_ino] : [[rn node] st_ino];
        NSNumber *inode = [NSNumber numberWithInt:ino];
        RestoreNode *existing = [hardlinks objectForKey:inode];
        if (existing != nil) {
            // Link.
            NSString *existingPath = [rootPath stringByAppendingPathComponent:[existing relativePath]];
            if (([existing node] == nil) != ([rn node] == nil)) {
                SETNSERROR(@"RestoreErrorDomain", -1, @"cannot link a directory to a file");
                HSLogError(@"can't link directory to a file");
                return NO;
            }
            if (link([existingPath fileSystemRepresentation], [restorePath fileSystemRepresentation]) == -1) {
                SETNSERROR(@"RestoreErrorDomain", -1, @"link(%@,%@): %s", existingPath, restorePath, strerror(errno));
                HSLogError(@"link() failed");
                return NO;
            }
            createdFile = YES;
        } else {
            [hardlinks setObject:rn forKey:inode];
        }
    }
    if (!createdFile) {
        Node *node = [rn node];
        if (node == nil) {
            Tree *tree = [rn tree];
            if (![[NSFileManager defaultManager] fileExistsAtPath:restorePath] && ![[NSFileManager defaultManager] createDirectoryAtPath:restorePath withIntermediateDirectories:NO attributes:nil error:error]) {
                HSLogError(@"error creating %@", restorePath);
                return NO;
            }
            if (![self applyTree:tree toPath:restorePath error:error]) {
                HSLogError(@"applyTree error");
                return NO;
            }
        } else {
            int mode = [node mode];
            BOOL isFifo = (mode & S_IFIFO) == S_IFIFO;
            if (isFifo) {
                if (mkfifo([restorePath fileSystemRepresentation], mode) == -1) {
                    SETNSERROR(@"RestoreErrorDomain", errno, @"mkfifo(%@): %s", restorePath, strerror(errno));
                    return NO;
                }
                if (![self applyNode:node toPath:restorePath error:error]) {
                    HSLogError(@"applyNode error");
                    return NO;
                }
            } else if ((mode & S_IFSOCK) == S_IFSOCK) {
                // Skip socket -- restoring it doesn't make any sense.
            } else if ((mode & S_IFREG) == 0 && ((mode & S_IFCHR) == S_IFCHR || (mode & S_IFBLK) == S_IFBLK)) {
                if (![[NSFileManager defaultManager] ensureParentPathExistsForPath:restorePath error:error]) {
                    return NO;
                }
                if (mknod([restorePath fileSystemRepresentation], mode, [node st_rdev]) == -1) {
                    SETNSERROR(@"RestorerErrorDomain", -1, @"mknod(%@): %s", restorePath, strerror(errno));
                    return NO;
                }
            } else {
                if (![self createFile:node atPath:restorePath error:error]) {
                    HSLogError(@"createFile error");
                    return NO;
                }
                if (![self applyNode:node toPath:restorePath error:error]) {
                    HSLogError(@"applyNode error");
                    return NO;
                }
            }
        }
        FileAttributes *fa = [[[FileAttributes alloc] initWithPath:restorePath error:error] autorelease];
        if (fa == nil) {
            return NO;
        }
        int flags = [fa flags];
        if (flags) {
            // Clear the flags temporarily so we can change ownership of the file.
            if (![fa applyFlags:0 error:error]) {
                return NO;
            }
        }
        int uid = [rn node] == nil ? [[rn tree] uid] : [[rn node] uid];
        int gid = [rn node] == nil ? [[rn tree] gid] : [[rn node] gid];
        NSError *chownError;
        if (![fa applyUID:uid gid:gid error:&chownError]) {
            fprintf(stderr, "error applying UID and GID to %s: %s\n", [restorePath fileSystemRepresentation], [[chownError localizedDescription] UTF8String]);
        }
        if (flags) {
            if (![fa applyFlags:flags error:error]) {
                return NO;
            }
        }
    }
    return YES;
}
- (BOOL)applyTree:(Tree *)tree toPath:(NSString *)path error:(NSError **)error {
    FileAttributes *fa = [[[FileAttributes alloc] initWithPath:path error:error] autorelease];
    if (!fa) {
        return NO;
    }
    if (![fa applyFinderFlags:[tree finderFlags] error:error]
        || ![fa applyExtendedFinderFlags:[tree extendedFinderFlags] error:error]) {
        return NO;
    }
    if (![self applyACLSHA1:[tree aclSHA1] toFileAttributes:fa error:error]) {
        return NO;
    }
    if (![self applyXAttrsSHA1:[tree xattrsSHA1] toFile:path error:error]) {
        return NO;
    }
    if (([tree mode] & (S_ISUID|S_ISGID|S_ISVTX) != 0) && ![fa applyMode:[tree mode] error:error]) {
        return NO;
    }
    if (([tree mode] & S_IFLNK) != S_IFLNK && [tree treeVersion] >= 7 && ![fa applyMTimeSec:tree.mtime_sec mTimeNSec:tree.mtime_nsec error:error]) {
        return NO;
    }
    if (([tree treeVersion] >= 7) && ![fa applyCreateTimeSec:tree.createTime_sec createTimeNSec:tree.createTime_nsec error:error]) {
        return NO;
    }
    if (![fa applyFlags:[tree flags] error:error]) {
        return NO;
    }
    return YES;
}
- (BOOL)applyNode:(Node *)node toPath:(NSString *)path error:(NSError **)error {
    FileAttributes *fa = [[[FileAttributes alloc] initWithPath:path error:error] autorelease];
    if (!fa) {
        return NO;
    }
    if (![self applyACLSHA1:[node aclSHA1] toFileAttributes:fa error:error]) {
        return NO;
    }
    BOOL isFifo = ([node mode] & S_IFIFO) == S_IFIFO;
    if (!isFifo) {
        if (![fa applyFinderFlags:[node finderFlags] error:error]
            || ![fa applyExtendedFinderFlags:[node extendedFinderFlags] error:error]
            || ![self applyXAttrsSHA1:[node xattrsSHA1] toFile:path error:error]
            || ![fa applyFinderFileType:[node finderFileType] finderFileCreator:[node finderFileCreator] error:error]) {
            return NO;
        }
    }
    if (([node mode] & (S_ISUID|S_ISGID|S_ISVTX) != 0) && ![fa applyMode:[node mode] error:error]) {
        return NO;
    }
    if (([node mode] & S_IFLNK) != S_IFLNK && [node treeVersion] >= 7 && ![fa applyMTimeSec:node.mtime_sec mTimeNSec:node.mtime_nsec error:error]) {
        return NO;
    }
    if (([node treeVersion] >= 7) && ![fa applyCreateTimeSec:node.createTime_sec createTimeNSec:node.createTime_nsec error:error]) {
        return NO;
    }
    if (!isFifo) {
        if (![fa applyFlags:[node flags] error:error]) {
            return NO;
        }
    }
    return YES;
}
- (BOOL)createFile:(Node *)node atPath:(NSString *)path error:(NSError **)error {
    if (![[NSFileManager defaultManager] ensureParentPathExistsForPath:path error:error]) {
        HSLogError(@"error ensuring path %@ exists", path);
        return NO;
    }
    if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        if (![[NSFileManager defaultManager] removeItemAtPath:path error:error]) {
            HSLogError(@"error removing existing file %@", path);
            return NO;
        }
    }
    HSLogTrace(@"%qu bytes -> %@", [node dataSize], path);
    if (([node mode] & S_IFLNK) == S_IFLNK) {
        NSData *data = [repo blobDataForSHA1s:[node dataSHA1s] error:error];
        if (data == nil) {
            HSLogError(@"error getting data for %@", [node dataSHA1s]);
            return NO;
        }
        NSString *target = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
        if (![self createSymLink:node path:path target:target error:error]) {
            HSLogError(@"error creating sym link %@", path);
            return NO;
        }
    } else if ([node dataSize] > 0) {
        if (![self createFileAtPath:path fromSHA1s:[node dataSHA1s] error:error]) {
            return NO;
        }
    } else {
        // It's a zero-byte file.
        int fd = open([path fileSystemRepresentation], O_CREAT|O_EXCL, [node mode]);
        if (fd == -1) {
            SETNSERROR(@"UnixErrorDomain", errno, @"%s: %@", strerror(errno), path);
            HSLogError(@"error opening %@", path);
            return NO;
        }
        close(fd);
    }
    return YES;
}
- (BOOL)createFileAtPath:(NSString *)path fromSHA1s:(NSArray *)dataSHA1s error:(NSError **)error {
    FileOutputStream *fos = [[FileOutputStream alloc] initWithPath:path append:NO];
    BOOL ret = YES;
    for (NSString *sha1 in dataSHA1s) {
        if (![self appendBlobForSHA1:sha1 toFile:fos error:error]) {
            ret = NO;
            break;
        }
    }
    [fos release];
    return ret;
}
- (BOOL)appendBlobForSHA1:(NSString *)sha1 toFile:(FileOutputStream *)fos error:(NSError **)error {
    int i = 0;
    BOOL ret = NO;
    NSError *myError = nil;
    NSAutoreleasePool *pool = nil;
    for (;;) {
        [pool drain];
        pool = [[NSAutoreleasePool alloc] init];
        if ([self doAppendBlobForSHA1:sha1 toFile:fos error:&myError]) {
            ret = YES;
            break;
        }
        [[StreamPairFactory theFactory] clear];
        BOOL isNetworkError = [[myError domain] isEqualToString:[CFStreamPair errorDomain]];
        // Retry indefinitely on network errors:
        if (!isNetworkError && (++i >= MAX_RETRIES)) {
            HSLogError(@"failed to get blob %@ after %d retries: %@", sha1, i, [myError localizedDescription]);
            break;
        }
        HSLogWarn(@"error appending blob %@ to file %@ (retrying): %@", sha1, [fos path], [myError localizedDescription]);
        // Seek back to the starting offset for this blob:
        if (![fos seekTo:writtenToCurrentFile error:&myError]) {
            ret = NO;
            break;
        }
    }
    [myError retain];
    [pool drain];
    [myError autorelease];
    if (error != NULL) {
        *error = myError;
    }
    return ret;
}
- (BOOL)doAppendBlobForSHA1:(NSString *)sha1 toFile:(FileOutputStream *)fos error:(NSError **)error {
    if (error != NULL) {
        *error = nil;
    }
    ServerBlob *sb = [[repo newServerBlobForSHA1:sha1 error:error] autorelease];
    if (sb == nil) {
        return NO;
    }
    id <InputStream> is = [[sb newInputStream] autorelease];
    BOOL ret = YES;
    NSAutoreleasePool *pool = nil;
    unsigned char *buf = (unsigned char *)malloc(MY_BUF_SIZE);
    for (;;) {
        [pool drain];
        pool = [[NSAutoreleasePool alloc] init];
        NSUInteger received = [is read:buf bufferLength:MY_BUF_SIZE error:error];
        if (received < 0) {
            ret = NO;
            break;
        }
        if (received == 0) {
            break;
        }
        if (![fos write:buf length:received error:error]) {
            ret = NO;
            break;
        }
        writtenToCurrentFile += received;
    }
    free(buf);
    if (error != NULL) {
        [*error retain];
    }
    [pool drain];
    if (error != NULL) {
        [*error autorelease];
    }
    return ret;
}
- (BOOL)createSymLink:(Node *)node path:(NSString *)symLinkFile target:(NSString *)target error:(NSError **)error {
    struct stat st;
    if (lstat([symLinkFile fileSystemRepresentation], &st) == 0) {
        if (![[NSFileManager defaultManager] removeItemAtPath:symLinkFile error:error]) {
            return NO;
        }
    }
    if (symlink([target fileSystemRepresentation], [symLinkFile fileSystemRepresentation]) == -1) {
        SETNSERROR(@"UnixErrorDomain", errno, @"symlink(%@): %s", symLinkFile, strerror(errno));
        return NO;
    }
    return YES;
}
- (BOOL)applyACLSHA1:(NSString *)aclSHA1 toFileAttributes:(FileAttributes *)fa error:(NSError **)error {
    if (aclSHA1 != nil) {
        NSData *data = [repo blobDataForSHA1:aclSHA1 error:error];
        if (data == nil) {
            return NO;
        }
        NSString *aclString = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
        if (![fa applyAcl:aclString error:error]) {
            return NO;
        }
    }
    return YES;
}
- (BOOL)applyXAttrsSHA1:(NSString *)xattrsSHA1 toFile:(NSString *)path error:(NSError **)error {
    if (xattrsSHA1 != nil) {
        NSData *xattrsData = [repo blobDataForSHA1:xattrsSHA1 error:error];
        if (xattrsData == nil) {
            return NO;
        }
        DataInputStream *is = [xattrsData newInputStream];
        BufferedInputStream *bis = [[BufferedInputStream alloc] initWithUnderlyingStream:is];
        XAttrSet *set = [[[XAttrSet alloc] initWithBufferedInputStream:bis error:error] autorelease];
        [bis release];
        [is release];
        if (!set) {
            return NO;
        }
        if (![set applyToFile:path error:error]) {
            return NO;
        }
    }
    return YES;
}
@end
