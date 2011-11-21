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
#import "NSErrorCodes.h"
#import "BufferedInputStream.h"
#import "BufferedOutputStream.h"
#import "NSData-Gzip.h"
#import "GunzipInputStream.h"
#import "FileACL.h"
#import "BlobKey.h"


#define MAX_RETRIES (10)
#define MY_BUF_SIZE (8192)

@interface Restorer (internal)
+ (NSString *)errorDomain;

- (BOOL)restoreTree:(Tree *)theTree toPath:(NSString *)thePath error:(NSError **)error;
- (BOOL)restoreNode:(Node *)theNode ofTree:(Tree *)theTree toPath:(NSString *)thePath error:(NSError **)error;
- (BOOL)needSuperUserForTree:(Tree *)theTree;
- (BOOL)needSuperUserForTree:(Tree *)theTree node:(Node *)theNode;
- (BOOL)chownNode:(Node *)theNode ofTree:(Tree *)theTree atPath:(NSString *)thePath error:(NSError **)error;
- (BOOL)chownTree:(Tree *)theTree atPath:(NSString *)thePath error:(NSError **)error;
- (BOOL)applyUID:(int)theUID gid:(int)theGID mode:(int)theMode rdev:(int)theRdev toPath:(NSString *)thePath error:(NSError **)error;
- (BOOL)applyTree:(Tree *)tree toPath:(NSString *)restorePath error:(NSError **)error;
- (BOOL)applyNode:(Node *)node toPath:(NSString *)restorePath error:(NSError **)error;
- (BOOL)createFile:(Node *)node atPath:(NSString *)path error:(NSError **)error;
- (BOOL)createFileAtPath:(NSString *)path fromBlobKeys:(NSArray *)dataBlobKeys uncompress:(BOOL)uncompress error:(NSError **)error;
- (BOOL)appendBlobForBlobKey:(BlobKey *)theBlobKey uncompress:(BOOL)uncompress to:(FileOutputStream *)fos error:(NSError **)error;
- (BOOL)doAppendBlobForBlobKey:(BlobKey *)theBlobKey uncompress:(BOOL)uncompress to:(BufferedOutputStream *)bos error:(NSError **)error;
- (BOOL)createSymLink:(Node *)node path:(NSString *)symLinkFile target:(NSString *)target error:(NSError **)error;
- (BOOL)applyACLBlobKey:(BlobKey *)aclBlobKey uncompress:(BOOL)uncompress toPath:(NSString *)path error:(NSError **)error;
- (BOOL)applyXAttrsBlobKey:(BlobKey *)xattrsBlobKey uncompress:(BOOL)uncompress toFile:(NSString *)path error:(NSError **)error;
- (void)addError:(NSError *)theError forPath:(NSString *)thePath;
@end

@implementation Restorer
- (id)initWithRepo:(ArqRepo *)theArqRepo bucketName:(NSString *)theBucketName commitSHA1:(NSString *)theCommitSHA1 {
    if (self = [super init]) {
        repo = [theArqRepo retain];
        bucketName = [theBucketName copy];
        commitSHA1 = [theCommitSHA1 copy];
        rootPath = [[[[NSFileManager defaultManager] currentDirectoryPath] stringByAppendingPathComponent:theBucketName] copy];
        restoreNodes = [[NSMutableArray alloc] init];
        hardlinks = [[NSMutableDictionary alloc] init];
        errorsByPath = [[NSMutableDictionary alloc] init];
        myUID = geteuid();
        myGID = getgid();
    }
    return self;
}
- (void)dealloc {
    [repo release];
    [bucketName release];
    [commitSHA1 release];
    [rootPath release];
    [restoreNodes release];
    [hardlinks release];
    [errorsByPath release];
    [rootTree release];
    [super dealloc];
}
- (BOOL)restore:(NSError **)error {
    if ([[NSFileManager defaultManager] fileExistsAtPath:rootPath]) {
        SETNSERROR([Restorer errorDomain], -1, @"%@ already exists", rootPath);
        return NO;
    }
    if (![[NSFileManager defaultManager] createDirectoryAtPath:rootPath withIntermediateDirectories:YES attributes:nil error:error]) {
        HSLogError(@"failed to create directory %@", rootPath);
        return NO;
    }
    BlobKey *commitBlobKey = nil;
    Commit *commit = nil;
    NSError *myError = nil;
    if (commitSHA1 != nil) {
        commitBlobKey = [[[BlobKey alloc] initWithSHA1:commitSHA1 stretchEncryptionKey:YES] autorelease];
        commit = [repo commitForBlobKey:commitBlobKey error:&myError];
        if (commit == nil) {
            HSLogError(@"error attempting to read commit for %@", commitBlobKey);
            
            // Try without stretched encryption key.
            commitBlobKey = [[[BlobKey alloc] initWithSHA1:commitSHA1 stretchEncryptionKey:NO] autorelease];
            commit = [repo commitForBlobKey:commitBlobKey error:&myError];
            if (commit == nil) {
                HSLogError(@"error attempting to read commit for %@", commitBlobKey);
                if (error != NULL) {
                    *error = myError;
                }
                return NO;
            }
        }
    } else {
        commitBlobKey = [[repo headBlobKey:error] retain];
        if (commitBlobKey == nil) {
            SETNSERROR([Restorer errorDomain], -1, @"no backup found");
            return NO;
        }
        commit = [repo commitForBlobKey:commitBlobKey error:error];
        if (commit == nil) {
            return NO;
        }
    }
    printf("restoring %scommit %s\n", (commitSHA1 == nil ? "head " : ""), [[commitBlobKey description] UTF8String]);
    
    rootTree = [[repo treeForBlobKey:[commit treeBlobKey] error:error] retain];
    if (rootTree == nil) {
        return NO;
    }
    if (![self restoreTree:rootTree toPath:rootPath error:error]) {
        return NO;
    }
    return YES;
}
- (NSDictionary *)errorsByPath {
    return errorsByPath;
}
@end

@implementation Restorer (internal)
+ (NSString *)errorDomain {
    return @"RestorerErrorDomain";
}

- (BOOL)restoreTree:(Tree *)theTree toPath:(NSString *)thePath error:(NSError **)error {
    NSNumber *inode = [NSNumber numberWithInt:[theTree st_ino]];
    NSString *existing = nil;
    if ([theTree st_nlink] > 1) {
        existing = [hardlinks objectForKey:inode];
    }
    if (existing != nil) {
        // Link.
        if (link([existing fileSystemRepresentation], [thePath fileSystemRepresentation]) == -1) {
            int errnum = errno;
            SETNSERROR([Restorer errorDomain], -1, @"link(%@,%@): %s", existing, thePath, strerror(errnum));
            HSLogError(@"link() failed");
            return NO;
        }
    } else {
        if (![[NSFileManager defaultManager] fileExistsAtPath:thePath] 
            && ![[NSFileManager defaultManager] createDirectoryAtPath:thePath withIntermediateDirectories:YES attributes:nil error:error]) {
            return NO;
        }
        NSAutoreleasePool *pool = nil;
        BOOL ret = YES;
        for (NSString *childNodeName in [theTree childNodeNames]) {
            [pool drain];
            pool = [[NSAutoreleasePool alloc] init];
            Node *childNode = [theTree childNodeWithName:childNodeName];
            NSString *childPath = [thePath stringByAppendingPathComponent:childNodeName];
            if ([childNode isTree]) {
                Tree *childTree = [repo treeForBlobKey:[childNode treeBlobKey] error:error];
                if (childTree == nil) {
                    ret = NO;
                    break;
                }
                NSError *restoreError = nil;
                if (![self restoreTree:childTree toPath:childPath error:&restoreError]) {
                    HSLogDebug(@"error restoring %@: %@", childPath, restoreError);
                    if ([restoreError isErrorWithDomain:[Restorer errorDomain] code:ERROR_ABORT_REQUESTED]) {
                        ret = NO;
                        if (error != NULL) {
                            *error = restoreError;
                        }
                        break;
                    }
                    [self addError:restoreError forPath:childPath];
                }
            } else {
                NSError *restoreError = nil;
                if (![self restoreNode:childNode ofTree:theTree toPath:childPath error:&restoreError]) {
                    if ([restoreError isErrorWithDomain:[Restorer errorDomain] code:ERROR_ABORT_REQUESTED]) {
                        ret = NO;
                        if (error != NULL) {
                            *error = restoreError;
                        }
                        break;
                    }
                    HSLogDebug(@"error restoring %@: %@", childPath, restoreError);
                    [self addError:restoreError forPath:childPath];
                }
            }
        }
        if (error != NULL) { [*error retain]; }
        [pool drain];
        if (error != NULL) { [*error autorelease]; }
        if (!ret) {
            return NO;
        }
        
        if (![self applyTree:theTree toPath:thePath error:error]) {
            return NO;
        }
        [hardlinks setObject:thePath forKey:inode];
        if ([self needSuperUserForTree:theTree]) {
            superUserNodeCount++;
        }
    }
    return YES;
}
- (BOOL)restoreNode:(Node *)theNode ofTree:(Tree *)theTree toPath:(NSString *)thePath error:(NSError **)error {
    NSAssert(theNode != nil, @"theNode can't be nil");
    NSAssert(theTree != nil, @"theTree can't be nil");
    
    NSNumber *inode = [NSNumber numberWithInt:[theNode st_ino]];
    NSString *existing = nil;
    if ([theNode st_nlink] > 1) {
        existing = [hardlinks objectForKey:inode];
    }
    if (existing != nil) {
        // Link.
        if (link([existing fileSystemRepresentation], [thePath fileSystemRepresentation]) == -1) {
            int errnum = errno;
            SETNSERROR([Restorer errorDomain], -1, @"link(%@,%@): %s", existing, thePath, strerror(errnum));
            HSLogError(@"link() failed");
            return NO;
        }
    } else {
        int mode = [theNode mode];
        if (S_ISFIFO(mode)) {
            if (mkfifo([thePath fileSystemRepresentation], mode) == -1) {
                int errnum = errno;
                SETNSERROR([Restorer errorDomain], errnum, @"mkfifo(%@): %s", thePath, strerror(errnum));
                return NO;
            }
            if (![self applyNode:theNode toPath:thePath error:error]) {
                HSLogError(@"applyNode error");
                return NO;
            }
        } else if (S_ISSOCK(mode)) {
            // Skip socket -- restoring it doesn't make any sense.
        } else if (S_ISCHR(mode)) {
            // character device: needs to be done as super-user.
        } else if (S_ISBLK(mode)) {
            // block device: needs to be done as super-user.
        } else {
            if (![self createFile:theNode atPath:thePath error:error]) {
                HSLogError(@"createFile error");
                return NO;
            }
            if (![self applyNode:theNode toPath:thePath error:error]) {
                HSLogError(@"applyNode error");
                return NO;
            }
        }
        [hardlinks setObject:thePath forKey:inode];
        if ([self needSuperUserForTree:theTree node:theNode]) {
            superUserNodeCount++;
        }
    }    
    return YES;
}
- (BOOL)needSuperUserForTree:(Tree *)theTree {
    NSAssert(theTree != nil, @"theTree can't be nil");
    
    int uid = [theTree uid];
    int gid = [theTree gid];
    int mode = [theTree mode];
    if ((uid != myUID) || (gid != myGID)) {
        return YES;
    }
    if (mode & (S_ISUID|S_ISGID|S_ISVTX)) {
        return YES;
    }
    return NO;
}
- (BOOL)needSuperUserForTree:(Tree *)theTree node:(Node *)theNode {
    NSAssert(theNode != nil, @"theNode can't be nil");
    NSAssert(theTree != nil, @"theTree can't be nil");
    
    int uid = [theNode uid];
    int gid = [theNode gid];
    int mode = [theNode mode];
    if ([theTree treeVersion] >= 7 && (S_ISCHR(mode) || S_ISBLK(mode))) {
        return YES;
    }
    if ((uid != myUID) || (gid != myGID)) {
        return YES;
    }
    if (mode & (S_ISUID|S_ISGID|S_ISVTX)) {
        return YES;
    }
    return NO;
}
- (BOOL)chownNode:(Node *)theNode ofTree:(Tree *)theTree atPath:(NSString *)thePath error:(NSError **)error {
    if ([[errorsByPath allKeys] containsObject:thePath]) {
        HSLogDebug(@"error restoring %@; skipping chownNode", thePath);
        return YES;
    }
    if ([self needSuperUserForTree:theTree node:theNode]) {
        if (![self applyUID:[theNode uid] gid:[theNode gid] mode:[theNode mode] rdev:[theNode st_rdev] toPath:thePath error:error]) {
            return NO;
        }
    }
    return YES;
}
- (BOOL)chownTree:(Tree *)theTree atPath:(NSString *)thePath error:(NSError **)error {
    if ([[errorsByPath allKeys] containsObject:thePath]) {
        HSLogDebug(@"error restoring %@; skipping chownTree", thePath);
        return YES;
    }
    
    NSAutoreleasePool *pool = nil;
    BOOL ret = YES;
    for (NSString *childNodeName in [theTree childNodeNames]) {
        [pool drain];
        pool = [[NSAutoreleasePool alloc] init];
        Node *childNode = [theTree childNodeWithName:childNodeName];
        NSString *childPath = [thePath stringByAppendingPathComponent:childNodeName];
        if ([childNode isTree]) {
            Tree *childTree = [repo treeForBlobKey:[childNode treeBlobKey] error:error];
            if (childTree == nil) {
                ret = NO;
                break;
            }
            if (![self chownTree:childTree atPath:childPath error:error]) {
                ret = NO;
                break;
            }
        } else {
            if (![self chownNode:childNode ofTree:theTree atPath:childPath error:error]) {
                ret = NO;
                break;
            }
        }
    }
    if (error != NULL) { [*error retain]; }
    [pool drain];
    if (error != NULL) { [*error autorelease]; }
    if (!ret) {
        return NO;
    }
    
    if ([self needSuperUserForTree:theTree]) {
        if (![self applyUID:[theTree uid] gid:[theTree gid] mode:[theTree mode] rdev:[theTree st_rdev] toPath:thePath error:error]) {
            return NO;
        }
    }
    return YES;
}
- (BOOL)applyUID:(int)theUID gid:(int)theGID mode:(int)theMode rdev:(int)theRdev toPath:(NSString *)thePath error:(NSError **)error {
    if (S_ISCHR(theMode) || S_ISBLK(theMode)) {
        if (![[NSFileManager defaultManager] ensureParentPathExistsForPath:thePath error:error]) {
            return NO;
        }
        HSLogDebug(@"mknod(%@, %d, %d)", thePath, theMode, theRdev);
        if (mknod([thePath fileSystemRepresentation], theMode, theRdev) == -1) {
            int errnum = errno;
            HSLogError(@"mknod(%@) error %d: %s", thePath, errnum, strerror(errnum));
            SETNSERROR([Restorer errorDomain], -1, @"failed to make device node %@: %s", thePath, strerror(errnum));
            return NO;
        }
    }
    FileAttributes *fa = [[[FileAttributes alloc] initWithPath:thePath error:error] autorelease];
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
    if (![fa applyMode:theMode error:error]) {
        return NO;
    }
    if (![fa applyUID:theUID gid:theGID error:error]) {
        return NO;
    }
    if (flags) {
        if (![fa applyFlags:flags error:error]) {
            return NO;
        }
    }
    return YES;
}
- (BOOL)applyTree:(Tree *)tree toPath:(NSString *)path error:(NSError **)error {
    FileAttributes *fa = [[[FileAttributes alloc] initWithPath:path error:error] autorelease];
    if (!fa) {
        return NO;
    }
    if (![self applyXAttrsBlobKey:[tree xattrsBlobKey] uncompress:[tree xattrsAreCompressed] toFile:path error:error]) {
        return NO;
    }
    if (![fa applyFinderFlags:[tree finderFlags] error:error]
        || ![fa applyExtendedFinderFlags:[tree extendedFinderFlags] error:error]) {
        return NO;
    }
    if (([tree mode] & (S_ISUID|S_ISGID|S_ISVTX)) && ![fa applyMode:[tree mode] error:error]) {
        return NO;
    }
    if (!S_ISLNK([tree mode]) && [tree treeVersion] >= 7 && ![fa applyMTimeSec:tree.mtime_sec mTimeNSec:tree.mtime_nsec error:error]) {
        return NO;
    }
    if (([tree treeVersion] >= 7) && ![fa applyCreateTimeSec:tree.createTime_sec createTimeNSec:tree.createTime_nsec error:error]) {
        return NO;
    }
    if (![fa applyFlags:[tree flags] error:error]) {
        return NO;
    }
    if (![self applyACLBlobKey:[tree aclBlobKey] uncompress:[tree aclIsCompressed] toPath:path error:error]) {
        return NO;
    }
    return YES;
}
- (BOOL)applyNode:(Node *)node toPath:(NSString *)path error:(NSError **)error {
    FileAttributes *fa = [[[FileAttributes alloc] initWithPath:path error:error] autorelease];
    if (!fa) {
        return NO;
    }
    if (![self applyXAttrsBlobKey:[node xattrsBlobKey] uncompress:[node xattrsAreCompressed] toFile:path error:error]) {
        return NO;
    }
    if (![self applyACLBlobKey:[node aclBlobKey] uncompress:[node aclIsCompressed] toPath:path error:error]) {
        return NO;
    }
    if (!S_ISFIFO([node mode])) {
        if (![fa applyFinderFlags:[node finderFlags] error:error]
            || ![fa applyExtendedFinderFlags:[node extendedFinderFlags] error:error]
            || ![fa applyFinderFileType:[node finderFileType] finderFileCreator:[node finderFileCreator] error:error]) {
            return NO;
        }
    }
    if (!([node mode] & (S_ISUID|S_ISGID|S_ISVTX))) {
        if (![fa applyMode:[node mode] error:error]) {
            return NO;
        }
    }
    if (!S_ISLNK([node mode]) && [node treeVersion] >= 7 && ![fa applyMTimeSec:node.mtime_sec mTimeNSec:node.mtime_nsec error:error]) {
        return NO;
    }
    if (([node treeVersion] >= 7) && ![fa applyCreateTimeSec:node.createTime_sec createTimeNSec:node.createTime_nsec error:error]) {
        return NO;
    }
    if (!S_ISFIFO([node mode])) {
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
    HSLogTrace(@"%qu bytes -> %@", [node uncompressedDataSize], path);
    if (S_ISLNK([node mode])) {
        NSMutableData *data = [NSMutableData data];
        for (BlobKey *dataBlobKey in [node dataBlobKeys]) {
            NSData *blobData = [repo blobDataForBlobKey:dataBlobKey error:error];
            if (blobData == nil) {
                HSLogError(@"error getting data for %@", dataBlobKey);
                return NO;
            }
            if ([node dataAreCompressed]) {
                blobData = [blobData gzipInflate];
            }
            [data appendData:blobData];
        }
        NSString *target = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
        if (![self createSymLink:node path:path target:target error:error]) {
            HSLogError(@"error creating sym link %@", path);
            return NO;
        }
    } else if ([node uncompressedDataSize] > 0) {
        if (![self createFileAtPath:path fromBlobKeys:[node dataBlobKeys] uncompress:[node dataAreCompressed] error:error]) {
            NSError *myError = nil;
            if ([[NSFileManager defaultManager] fileExistsAtPath:path] && ![[NSFileManager defaultManager] removeItemAtPath:path error:&myError]) {
                HSLogError(@"error deleting incorrectly-restored file %@: %@", path, myError);
            }
            return NO;
        }
    } else {
        // It's a zero-byte file.
        int fd = open([path fileSystemRepresentation], O_CREAT|O_EXCL, S_IRWXU);
        if (fd == -1) {
            int errnum = errno;
            HSLogError(@"open(%@) error %d: %s", path, errnum, strerror(errnum));
            SETNSERROR(@"UnixErrorDomain", errnum, @"failed to open %@: %s", path, strerror(errnum));
            return NO;
        }
        close(fd);
    }
    HSLogDetail(@"restored %@", path);
    return YES;
}
- (BOOL)createFileAtPath:(NSString *)path fromBlobKeys:(NSArray *)dataBlobKeys uncompress:(BOOL)uncompress error:(NSError **)error {
    FileOutputStream *fos = [[FileOutputStream alloc] initWithPath:path append:NO];
    BOOL ret = YES;
    writtenToCurrentFile = 0;
    for (BlobKey *dataBlobKey in dataBlobKeys) {
        if (![self appendBlobForBlobKey:dataBlobKey uncompress:uncompress to:fos error:error]) {
            ret = NO;
            break;
        }
    }
    [fos release];
    return ret;
}
- (BOOL)appendBlobForBlobKey:(BlobKey *)theBlobKey uncompress:(BOOL)uncompress to:(FileOutputStream *)fos error:(NSError **)error {
    BOOL ret = NO;
    NSError *myError = nil;
    NSAutoreleasePool *pool = nil;
    unsigned long long transferredSoFar = transferred;
    unsigned long long writtenToCurrentFileSoFar = writtenToCurrentFile;
    for (;;) {
        [pool drain];
        pool = [[NSAutoreleasePool alloc] init];
        BufferedOutputStream *bos = [[[BufferedOutputStream alloc] initWithUnderlyingOutputStream:fos] autorelease];
        if ([self doAppendBlobForBlobKey:theBlobKey uncompress:uncompress to:bos error:&myError] && [bos flush:&myError]) {
            ret = YES;
            break;
        }
        if ([myError isErrorWithDomain:[Restorer errorDomain] code:ERROR_ABORT_REQUESTED]) {
            HSLogInfo(@"restore canceled");
            break;
        }
        if (![myError isTransientError]) {
            HSLogError(@"error getting appending blob %@ to %@: %@", theBlobKey, bos, myError);
            ret = NO;
            break;
        }
        HSLogWarn(@"error appending blob %@ to %@ (retrying): %@", theBlobKey, bos, [myError localizedDescription]);
        // Reset transferred:
        transferred = transferredSoFar;
        writtenToCurrentFile = writtenToCurrentFileSoFar;
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
- (BOOL)doAppendBlobForBlobKey:(BlobKey *)theBlobKey uncompress:(BOOL)uncompress to:(BufferedOutputStream *)bos error:(NSError **)error {
    ServerBlob *sb = [[repo newServerBlobForBlobKey:theBlobKey error:error] autorelease];
    if (sb == nil) {
        return NO;
    }
    id <InputStream> is = [[sb newInputStream] autorelease];
    if (uncompress) {
        is = [[[GunzipInputStream alloc] initWithUnderlyingStream:is] autorelease];
    }
    HSLogDebug(@"writing %@ to %@", is, bos);
    BOOL ret = YES;
    NSError *myError = nil;
    NSAutoreleasePool *pool = nil;
    unsigned char *buf = (unsigned char *)malloc(MY_BUF_SIZE);
    for (;;) {
        [pool drain];
        pool = [[NSAutoreleasePool alloc] init];
        NSInteger received = [is read:buf bufferLength:MY_BUF_SIZE error:&myError];
        if (received < 0) {
            ret = NO;
            break;
        }
        if (received == 0) {
            break;
        }
        if (![bos writeFully:buf length:received error:error]) {
            ret = NO;
            break;
        }
        
        transferred += received;
        writtenToCurrentFile += received;
    }
    free(buf);
    [myError retain];
    [pool drain];
    [myError autorelease];
    if (error != NULL) {
        *error = myError;
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
        int errnum = errno;
        HSLogError(@"symlink(%@, %@) error %d: %s", target, symLinkFile, errnum, strerror(errnum));
        SETNSERROR(@"UnixErrorDomain", errnum, @"failed to create symlink %@ to %@: %s", symLinkFile, target, strerror(errnum));
        return NO;
    }
    return YES;
}
- (BOOL)applyACLBlobKey:(BlobKey *)aclBlobKey uncompress:(BOOL)uncompress toPath:(NSString *)path error:(NSError **)error {
    if (aclBlobKey != nil) {
        NSData *data = [repo blobDataForBlobKey:aclBlobKey error:error];
        if (data == nil) {
            return NO;
        }
        if (uncompress) {
            data = [data gzipInflate];
        }
        NSString *aclString = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
        
        NSString *currentAclString = nil;
        if (![FileACL aclText:&currentAclString forFile:path error:error]) {
            return NO;
        }
        if (![currentAclString isEqualToString:aclString] && [aclString length] > 0) {
            if (![FileACL writeACLText:aclString toFile:path error:error]) {
                return NO;
            }
        }
    }
    return YES;
}
- (BOOL)applyXAttrsBlobKey:(BlobKey *)xattrsBlobKey uncompress:(BOOL)uncompress toFile:(NSString *)path error:(NSError **)error {
    if (xattrsBlobKey != nil) {
        NSData *xattrsData = [repo blobDataForBlobKey:xattrsBlobKey error:error];
        if (xattrsData == nil) {
            return NO;
        }
        id <InputStream> is = [xattrsData newInputStream];
        if (uncompress) {
            id <InputStream> uncompressed = [[GunzipInputStream alloc] initWithUnderlyingStream:is];
            [is release];
            is = uncompressed;
        }
        BufferedInputStream *bis = [[BufferedInputStream alloc] initWithUnderlyingStream:is];
        [is release];
        XAttrSet *set = [[[XAttrSet alloc] initWithBufferedInputStream:bis error:error] autorelease];
        [bis release];
        if (!set) {
            return NO;
        }
        if (![set applyToFile:path error:error]) {
            return NO;
        }
    }
    return YES;
}
- (void)addError:(NSError *)theError forPath:(NSString *)thePath {
    [errorsByPath setObject:theError forKey:thePath];
}
@end
