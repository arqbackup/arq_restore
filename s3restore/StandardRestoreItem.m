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



#import "StandardRestoreItem.h"
#import "Repo.h"
#import "Tree.h"
#import "Node.h"
#import "StandardRestorer.h"
#import "BlobKey.h"
#import "FileOutputStream.h"
#import "BufferedOutputStream.h"
#import "NSData-Compress.h"
#import "FileAttributes.h"
#import "OSStatusDescription.h"
#import "DataInputStream.h"
#import "BufferedInputStream.h"
#import "XAttrSet.h"
#import "FileACL.h"
#import "CacheOwnership.h"
#import "SHA1Hash.h"


enum {
    kRestoreActionRestoreTree=1,
    kRestoreActionRestoreNode=2,
    kRestoreActionApplyTree=3
} StandardRestoreAction;



@implementation StandardRestoreItem
- (id)initWithStandardRestorer:(StandardRestorer *)theStandardRestorer path:(NSString *)thePath tree:(Tree *)theTree {
    if (self = [super init]) {
        standardRestorer = [theStandardRestorer retain];
        path = [thePath retain];
        tree = [theTree retain];
        restoreAction = kRestoreActionRestoreTree;
    }
    return self;
}
- (id)initWithStandardRestorer:(StandardRestorer *)theStandardRestorer path:(NSString *)thePath tree:(Tree *)theTree node:(Node *)theNode {
    if (self = [super init]) {
        standardRestorer = [theStandardRestorer retain];
        path = [thePath retain];
        tree = [theTree retain];
        node = [theNode retain];
        restoreAction = kRestoreActionRestoreNode;
    }
    return self;
}
- (void)dealloc {
    [standardRestorer release];
    [path release];
    [tree release];
    [node release];
    [super dealloc];
}

- (NSString *)errorDomain {
    return @"StandardRestoreItemErrorDomain";
}

- (NSString *)path {
    return path;
}
- (BOOL)restore:(NSError **)error {
    BOOL ret = YES;
    switch (restoreAction) {
        case kRestoreActionRestoreTree:
            break;
        case kRestoreActionRestoreNode:
            ret = [self restoreNode:error];
            break;
        case kRestoreActionApplyTree:
            ret = [self applyTree:error];
            break;
        default:
            NSAssert(0==1, @"unknown restore action");
            break;
    }
    return ret;
}
- (NSArray *)nextItems:(NSError **)error {
    NSArray *ret = nil;
    switch (restoreAction) {
        case kRestoreActionRestoreTree:
            ret = [self nextItemsForTree:error];
            break;
        case kRestoreActionRestoreNode:
            ret = [NSArray array];
            break;
        case kRestoreActionApplyTree:
            ret = [NSArray array];
            break;
        default:
            NSAssert(0==1, @"unknown restore action");
            break;
    }
    return ret;
}


#pragma mark internal
- (id)initApplyItemWithStandardRestorer:(StandardRestorer *)theStandardRestorer tree:(Tree *)theTree path:(NSString *)thePath {
    if (self = [super init]) {
        standardRestorer = [theStandardRestorer retain];
        path = [thePath retain];
        tree = [theTree retain];
        restoreAction = kRestoreActionApplyTree;
    }
    return self;
}
- (BOOL)restoreNode:(NSError **)error {
    BOOL fileExists = NO;
    struct stat st;
    if (lstat([path fileSystemRepresentation], &st) == 0) {
        // File exists.
        if (st.st_mtimespec.tv_sec > [node mtime_sec]) {
            HSLogDebug(@"%@ is newer than the file in the backup record; not overwriting", path);
            SETNSERROR([self errorDomain], -1, @"Existing file on disk is newer; not overwriting");
            return NO;
        }
        
        if (st.st_mtimespec.tv_sec == [node mtime_sec]
                   && st.st_mtimespec.tv_nsec == [node mtime_nsec]
                   && st.st_size == [node uncompressedDataSize]) {
            HSLogDebug(@"%@ mtime and ctime match the backup record; not overwriting", path);
            HSLogDetail(@"%@ is already restored", path);
            if (![standardRestorer addToFileBytesRestored:st.st_size error:error]) {
                return NO;
            }
            fileExists = YES;
        }
    }
    if (!fileExists) {
        HSLogDebug(@"restoring file %@", path);
        NSString *existingPath = [standardRestorer hardlinkedPathForInode:[node st_ino]];
        if (existingPath != nil) {
            // Create hard link to the existing file:
            if (link([existingPath fileSystemRepresentation], [path fileSystemRepresentation]) == -1) {
                int errnum = errno;
                SETNSERROR([standardRestorer errorDomain], errnum, @"link(%@, %@): %s", existingPath, path, strerror(errnum));
                HSLogError(@"link(%@, %@): %s", existingPath, path, strerror(errnum));
                return NO;
            }
        } else {
            if (S_ISLNK([node mode])) {
                if (![self restoreLink:error]) {
                    return NO;
                }
            } else if (S_ISREG([node mode]) || [node mode] == 0 /* Windows */) {
                if (![self restoreRegularFile:error]) {
                    return NO;
                }
            } else {
                HSLogDetail(@"skipping restore of non-regular-file %@", path);
            }
            [standardRestorer setHardlinkedPath:path forInode:[node st_ino]];
        }
    }
    return YES;
}
- (BOOL)restoreLink:(NSError **)error {
    NSMutableData *data = [NSMutableData data];
    for (BlobKey *dataBlobKey in [node dataBlobKeys]) {
        NSData *blobData = [standardRestorer dataForBlobKey:dataBlobKey error:error];
        if (blobData == nil) {
            HSLogError(@"error getting data for %@", dataBlobKey);
            return NO;
        }

        blobData = [blobData uncompress:[dataBlobKey compressionType] error:error];
        if (blobData == nil) {
            return NO;
        }
        [data appendData:blobData];
    }
    NSString *target = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
    
    if (symlink([target fileSystemRepresentation], [path fileSystemRepresentation]) == -1) {
        int errnum = errno;
        HSLogError(@"symlink(%@, %@) error %d: %s", target, path, errnum, strerror(errnum));
        SETNSERROR(@"UnixErrorDomain", errnum, @"failed to create symlink %@ to %@: %s", path, target, strerror(errnum));
        return NO;
    }
    HSLogDetail(@"restored %@", path);
    
    NSError *myError = nil;
    if (![self applyNode:&myError]) {
        HSLogError(@"failed to set attributes of %@: %@", path, [myError localizedDescription]);
        SETERRORFROMMYERROR;
        return NO;
    }
    
    return YES;
}
- (BOOL)restoreRegularFile:(NSError **)error {
    if ([node uncompressedDataSize] > 0) {
        if ([[node dataBlobKeys] count] > 0) {
            BufferedOutputStream *bos = [[BufferedOutputStream alloc] initWithPath:path targetUID:[[CacheOwnership sharedCacheOwnership] uid] targetGID:[[CacheOwnership sharedCacheOwnership] gid] append:NO];
            BOOL ret = [self restoreFileDataToStream:bos error:error];
            if (ret) {
                ret = [bos flush:error];
            }
            [bos release];
            if (!ret) {
                HSLogDebug(@"error restoring file data; deleting incomplete file %@", path);
                NSError *rmError = nil;
                if ([[NSFileManager defaultManager] fileExistsAtPath:path] && ![[NSFileManager defaultManager] removeItemAtPath:path error:&rmError]) {
                    HSLogError(@"failed to delete incomplete file %@: %@", path, rmError);
                }
                return NO;
            }
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
        HSLogDetail(@"restored %@", path);
    }
    
    NSError *myError = nil;
    if (![self applyNode:&myError]) {
        HSLogError(@"failed to set attributes of %@: %@", path, [myError localizedDescription]);
        SETERRORFROMMYERROR;
        return NO;
    }
    
    return YES;
}
- (BOOL)restoreFileDataToStream:(BufferedOutputStream *)theBOS error:(NSError **)error {
    NSAutoreleasePool *pool = nil;
    BOOL ret = YES;
    HSLogDebug(@"restoring %@", [node dataBlobKeys]);
    for (NSUInteger index = 0; index < [[node dataBlobKeys] count]; index++) {
        [pool drain];
        pool = [[NSAutoreleasePool alloc] init];
        
        BlobKey *dataBlobKey = [[node dataBlobKeys] objectAtIndex:index];
        NSData *compressedData = [standardRestorer dataForBlobKey:dataBlobKey error:error];
        if (compressedData == nil) {
            ret = NO;
            break;
        }
        NSError *myError = nil;
        NSData *uncompressed = [compressedData uncompress:[dataBlobKey compressionType] error:&myError];
        if (uncompressed == nil) {
            HSLogError(@"failed to uncompress %@ (chunk #%ld of %ld) for %@: %@", dataBlobKey, index, [[node dataBlobKeys] count], path, myError);
            SETERRORFROMMYERROR;
            
//            // Save the blob to a file.
//            NSString *blobFilename = [[dataBlobKey sha1] stringByAppendingString:@".uncompress_error"];
//            NSString *blobPath = [[path stringByDeletingLastPathComponent] stringByAppendingPathComponent:blobFilename];
//            NSError *tmpError = nil;
//            if (![compressedData writeToFile:blobPath options:NSAtomicWrite error:&tmpError]) {
//                HSLogError(@"failed to write %@: %@", blobPath, tmpError);
//            } else {
//                HSLogInfo(@"saved data that couldn't be uncompressed to %@", blobPath);
//            }
//
//            // Try to decrypt the blob.
//            NSData *decryptedAgain = [[standardRestorer repo] decryptData:compressedData error:&myError];
//            if (decryptedAgain == nil) {
//                HSLogError(@"failed to decrypt data the second time: %@", myError);
//            } else {
//                HSLogError(@"decrypted the data the second time!");
//                uncompressed = [decryptedAgain uncompress:[dataBlobKey compressionType] error:&myError];
//                if (uncompressed == nil) {
//                    HSLogError(@"failed to uncompress second-time-decrypted data; %@", myError);
//                } else {
//                    HSLogError(@"successfully uncompressed the second-time-decrypted data!");
//                }
//            }

            if (![standardRestorer deleteBlobForBlobKey:dataBlobKey error:&myError]) {
                HSLogError(@"failed to delete invalid object %@: %@", dataBlobKey, myError);
            }
            
            ret = NO;
            break;
        }
        if (![standardRestorer addToFileBytesRestored:[uncompressed length] error:error]) {
            ret = NO;
            break;
        }
        if (![theBOS writeFully:[uncompressed bytes] length:[uncompressed length] error:error]) {
            ret = NO;
            break;
            return NO;
        }
        HSLogDebug(@"appended chunk %ld of %ld (%ld bytes) to %@", (unsigned long)index, (unsigned long)[[node dataBlobKeys] count], (unsigned long)[uncompressed length], path);
    }
    if (!ret && error != NULL) {
        [*error retain];
    }
    [pool drain];
    if (!ret && error != NULL) {
        [*error autorelease];
    }
    return ret;
}
- (BOOL)applyNode:(NSError **)error {
    HSLogDebug(@"applying attributes to file %@", path);
    NSError *xattrsError = nil;
    if ([node xattrsBlobKey] != nil && ![self applyXAttrsBlobKey:[node xattrsBlobKey] error:&xattrsError]) {
        HSLogError(@"failed to apply xattrs %@ to %@: %@", [node xattrsBlobKey], path, xattrsError);
    }
    if (([node uid] < 500 && [node gid] < 500) || ![standardRestorer useTargetUIDAndGID]) {
        NSError *aclError = nil;
        if ([node aclBlobKey] != nil && ![self applyACLBlobKey:[node aclBlobKey] error:&aclError]) {
            HSLogError(@"failed to apply acl %@ to %@: %@", [node aclBlobKey], path, aclError);
        }
    }
    
    if ([standardRestorer useTargetUIDAndGID]) {
        HSLogDebug(@"apply restorer %@ target UID %d and GID %d to %@", standardRestorer, [standardRestorer targetUID], [standardRestorer targetGID], path);
        if (![FileAttributes applyUID:[standardRestorer targetUID] gid:[standardRestorer targetGID] toPath:path error:error]) {
            return NO;
        }
    } else {
        HSLogDebug(@"apply node %@ UID %d and GID %d to %@", node, [node uid], [node gid], path);
        if (![FileAttributes applyUID:[node uid] gid:[node gid] toPath:path error:error]) {
            return NO;
        }
    }
    
    struct stat st;
    if (lstat([path fileSystemRepresentation], &st) == -1) {
        int errnum = errno;
        HSLogError(@"lstat(%@) error %d: %s", path, errnum, strerror(errnum));
        SETNSERROR(@"UnixErrorDomain", errnum, @"%@: %s", path, strerror(errnum));
        return NO;
    }
    
    FSRef fsRef;
    Boolean isDirectory;
    OSStatus oss = 0;
    if (S_ISLNK(st.st_mode)) {
        oss = SymlinkPathMakeRef((UInt8*)[path fileSystemRepresentation], &fsRef, &isDirectory);
    } else {
        oss = FSPathMakeRef((UInt8*)[path fileSystemRepresentation], &fsRef, &isDirectory);
    }
    if (oss != noErr) {
        HSLogInfo(@"skipping applying some metadata for %@: %@", path, [OSStatusDescription descriptionForOSStatus:oss]);
    } else {
        if (!S_ISFIFO([node mode])) {
            FileAttributes *fa = [[[FileAttributes alloc] initWithPath:path isSymLink:S_ISLNK([node mode]) error:error] autorelease];
            if (fa == nil) {
                return NO;
            }
            if ([fa finderFlags] != [node finderFlags] && ![FileAttributes applyFinderFlags:[node finderFlags] to:&fsRef isDirectory:NO error:error]) {
                return NO;
            }
            if ([fa extendedFinderFlags] != [node extendedFinderFlags] && ![FileAttributes applyExtendedFinderFlags:[node extendedFinderFlags] to:&fsRef isDirectory:NO error:error]) {
                return NO;
            }
            if ([node finderFileType] != nil || [node finderFileCreator] != nil) {
                if (![[fa finderFileType] isEqualToString:[node finderFileType]] || ![[fa finderFileCreator] isEqualToString:[node finderFileCreator]]) {
                    if (![FileAttributes applyFinderFileType:[node finderFileType] finderFileCreator:[node finderFileCreator] to:&fsRef error:error]) {
                        return NO;
                    }
                }
            }
        }
        if (([node treeVersion] >= 7) && ![FileAttributes applyCreateTimeSec:node.createTime_sec createTimeNSec:node.createTime_nsec to:&fsRef error:error]) {
            return NO;
        }
    }
    if (st.st_mode != [node mode] && ![FileAttributes applyMode:[node mode] toPath:path isDirectory:NO error:error]) {
        return NO;
    }
    if ([node treeVersion] >= 7 && ![FileAttributes applyMTimeSec:node.mtime_sec mTimeNSec:node.mtime_nsec toPath:path error:error]) {
        return NO;
    }
    if (!S_ISFIFO([node mode])) {
        if (st.st_flags != [node flags] && ![FileAttributes applyFlags:(unsigned long)[node flags] toPath:path error:error]) {
            return NO;
        }
    }
    return YES;
}
- (BOOL)applyXAttrsBlobKey:(BlobKey *)xattrsBlobKey error:(NSError **)error {
    NSAssert(xattrsBlobKey != nil, @"xattrsBlobKey may not be nil");
    NSData *xattrsData = [standardRestorer dataForBlobKey:xattrsBlobKey error:error];
    if (xattrsData == nil) {
        return NO;
    }
    xattrsData = [xattrsData uncompress:[xattrsBlobKey compressionType] error:error];
    if (xattrsData == nil) {
        return NO;
    }
    DataInputStream *dis = [[[DataInputStream alloc] initWithData:xattrsData description:[NSString stringWithFormat:@"xattrs %@", xattrsBlobKey]] autorelease];
    BufferedInputStream *bis = [[[BufferedInputStream alloc] initWithUnderlyingStream:dis] autorelease];
    XAttrSet *set = [[[XAttrSet alloc] initWithBufferedInputStream:bis error:error] autorelease];
    if (!set) {
        return NO;
    }
    if (![set applyToFile:path error:error]) {
        return NO;
    }
    return YES;
}
- (BOOL)applyACLBlobKey:(BlobKey *)theACLBlobKey error:(NSError **)error {
    NSAssert(theACLBlobKey != nil, @"theACLBlobKey may not be nil");
    NSData *data = [standardRestorer dataForBlobKey:theACLBlobKey error:error];
    if (data == nil) {
        return NO;
    }
    data = [data uncompress:[theACLBlobKey compressionType] error:error];
    if (data == nil) {
        return NO;
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
    return YES;
}
- (BOOL)applyTree:(NSError **)error {
    HSLogDebug(@"applying attributes to directory %@", path);
    
    if ([standardRestorer useTargetUIDAndGID]) {
        HSLogDebug(@"apply restorer %@ target UID %d and GID %dto %@", standardRestorer, [standardRestorer targetUID], [standardRestorer targetGID], path);
        if (![FileAttributes applyUID:[standardRestorer targetUID] gid:[standardRestorer targetGID] toPath:path error:error]) {
            return NO;
        }
    } else {
        HSLogDebug(@"apply tree %@ UID %d and GID %d to %@", tree, [tree uid], [tree gid], path);
        if (![FileAttributes applyUID:[tree uid] gid:[tree gid] toPath:path error:error]) {
            return NO;
        }
    }

    if ([tree xattrsBlobKey] != nil && ![self applyXAttrsBlobKey:[tree xattrsBlobKey] error:error]) {
        return NO;
    }
    
    FSRef fsRef;
    Boolean isDirectory;
    OSStatus oss = FSPathMakeRef((UInt8*)[path fileSystemRepresentation], &fsRef, &isDirectory);
    if (oss != noErr) {
        if (oss == bdNamErr) {
            HSLogInfo(@"not applying some metadata to %@: bad name", path);
            return YES;
        } else {
            SETNSERROR([self errorDomain], -1, @"%@", [OSStatusDescription descriptionForOSStatus:oss]);
            return NO;
        }
    }
    
    if ([tree st_ino] == 0) {
        HSLogDebug(@"st_ino is 0 (probably a Windows file); not applying mode, mtime or flags to %@", path);
    } else {
        if (![FileAttributes applyFinderFlags:[tree finderFlags] to:&fsRef isDirectory:YES error:error]
            || ![FileAttributes applyExtendedFinderFlags:[tree extendedFinderFlags] to:&fsRef isDirectory:YES error:error]) {
            return NO;
        }
        if (![FileAttributes applyMode:[tree mode] toPath:path isDirectory:YES error:error]) {
            return NO;
        }
        if (([tree treeVersion] >= 7) && ![FileAttributes applyCreateTimeSec:tree.createTime_sec createTimeNSec:tree.createTime_nsec to:&fsRef error:error]) {
            return NO;
        }
        if (![FileAttributes applyFlags:(unsigned long)[tree flags] toPath:path error:error]) {
            return NO;
        }
        if (([tree uid] < 500 && [tree gid] < 500) || ![standardRestorer useTargetUIDAndGID]) {
            if ([tree aclBlobKey] != nil && ![self applyACLBlobKey:[tree aclBlobKey] error:error]) {
                return NO;
            }
        }
        if ([tree treeVersion] >= 7 && ![FileAttributes applyMTimeSec:tree.mtime_sec mTimeNSec:tree.mtime_nsec toPath:path error:error]) {
            return NO;
        }
    }

    return YES;
}
- (NSArray *)nextItemsForTree:(NSError **)error {
    NSMutableArray *nextItems = [NSMutableArray array];
    NSAutoreleasePool *pool = nil;
    for (NSString *childNodeName in [tree childNodeNames]) {
        [pool drain];
        pool = [[NSAutoreleasePool alloc] init];
        Node *childNode = [tree childNodeWithName:childNodeName];
        NSString *childPath = [path stringByAppendingPathComponent:childNodeName];
        if ([childNode isTree]) {
            Tree *childTree = [standardRestorer treeForBlobKey:[childNode treeBlobKey] error:error];
            if (childTree == nil) {
                nextItems = nil;
                break;
            }
            StandardRestoreItem *childRestoreItem = [[[StandardRestoreItem alloc] initWithStandardRestorer:standardRestorer path:childPath tree:childTree] autorelease];
            [nextItems addObject:childRestoreItem];
        } else {
            StandardRestoreItem *childRestoreItem = [[[StandardRestoreItem alloc] initWithStandardRestorer:standardRestorer path:childPath tree:tree node:childNode] autorelease];
            [nextItems addObject:childRestoreItem];
        }
    }
    if (nextItems == nil && error != NULL) {
        [*error retain];
    }
    [pool drain];
    if (nextItems == nil && error != NULL) {
        [*error autorelease];
    }
    if (nextItems == nil) {
        return nil;
    }
    StandardRestoreItem *treeRestoreItem = [[[StandardRestoreItem alloc] initApplyItemWithStandardRestorer:standardRestorer tree:tree path:path] autorelease];
    [nextItems addObject:treeRestoreItem];
    return nextItems;
}

@end
