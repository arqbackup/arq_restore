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


#import "RestoreItem.h"
#import "Tree.h"
#import "Node.h"
#import "Repo.h"
#import "OSStatusDescription.h"
#import "FileAttributes.h"
#import "FileACL.h"
#import "DataInputStream.h"
#import "BufferedInputStream.h"
#import "BlobKey.h"
#import "NSData-GZip.h"
#import "XAttrSet.h"
#import "Restorer.h"
#import "NSFileManager_extra.h"
#import "FileOutputStream.h"
#import "BufferedOutputStream.h"


enum {
    kRestoreActionRestoreTree=1,
    kRestoreActionRestoreNode=2,
    kRestoreActionApplyTree=3,
    kRestoreActionRestoreFileData=4
} RestoreAction;


@implementation RestoreItem
- (id)initWithPath:(NSString *)thePath tree:(Tree *)theTree {
    if (self = [super init]) {
        path = [thePath retain];
        tree = [theTree retain];
        restoreAction = kRestoreActionRestoreTree;
    }
    return self;
}
- (id)initWithPath:(NSString *)thePath tree:(Tree *)theTree node:(Node *)theNode {
    if (self = [super init]) {
        path = [thePath retain];
        tree = [theTree retain];
        node = [theNode retain];
        restoreAction = kRestoreActionRestoreNode;
    }
    return self;
}
- (id)initWithPath:(NSString *)thePath tree:(Tree *)theTree node:(Node *)theNode fileOutputStream:(FileOutputStream *)theFileOutputStream dataBlobKeyIndex:(NSUInteger)theDataBlobKeyIndex {
    if (self = [super init]) {
        path = [thePath retain];
        tree = [theTree retain];
        node = [theNode retain];
        fileOutputStream = [theFileOutputStream retain];
        dataBlobKeyIndex = theDataBlobKeyIndex;
        restoreAction = kRestoreActionRestoreFileData;
    }
    return self;
}

- (void)dealloc {
    [tree release];
    [node release];
    [path release];
    [fileOutputStream release];
    [super dealloc];
}

- (NSString *)errorDomain {
    return @"RestoreItemErrorDomain";
}
- (NSString *)path {
    return path;
}
- (BOOL)restoreWithHardlinks:(NSMutableDictionary *)theHardlinks restorer:(id <Restorer>)theRestorer error:(NSError **)error {
    BOOL ret = NO;
    switch (restoreAction) {
        case kRestoreActionRestoreTree:
            ret = [self restoreTreeWithHardlinks:theHardlinks restorer:theRestorer error:error];
            break;
        case kRestoreActionRestoreNode:
            ret = [self restoreNodeWithHardlinks:theHardlinks restorer:theRestorer error:error];
            break;
        case kRestoreActionApplyTree:
            ret = [self applyTreeWithHardlinks:theHardlinks restorer:theRestorer error:error];
            break;
        case kRestoreActionRestoreFileData:
            ret = [self restoreFileDataWithRestorer:theRestorer error:error];
            break;
        default:
            NSAssert(0==1, @"unknown restore action");
            break;
    }
    return ret;
}
- (NSArray *)nextItemsWithRepo:(Repo *)theRepo error:(NSError **)error {
    NSArray *ret = nil;
    switch (restoreAction) {
        case kRestoreActionRestoreTree:
            ret = [self nextItemsForTreeWithRepo:theRepo error:error];
            break;
        case kRestoreActionRestoreFileData:
        case kRestoreActionRestoreNode:
            if (!errorOccurred && fileOutputStream != nil && [[node dataBlobKeys] count] > dataBlobKeyIndex) {
                RestoreItem *nextItem = [[[RestoreItem alloc] initWithPath:path tree:tree node:node fileOutputStream:fileOutputStream dataBlobKeyIndex:dataBlobKeyIndex] autorelease];
                ret = [NSArray arrayWithObject:nextItem];
            } else {
                ret = [NSArray array];
            }
            break;
        case kRestoreActionApplyTree:
            ret = [NSArray array];
            break;
            break;
        default:
            NSAssert(0==1, @"unknown restore action");
            break;
    }
    return ret;
}


#pragma mark internal
- (id)initApplyItemWithTree:(Tree *)theTree path:(NSString *)thePath {
    if (self = [super init]) {
        tree = [theTree retain];
        restoreAction = kRestoreActionApplyTree;
        path = [thePath retain];
    }
    return self;
}

- (BOOL)restoreTreeWithHardlinks:(NSMutableDictionary *)theHardlinks restorer:(id <Restorer>)theRestorer error:(NSError **)error {
    NSNumber *inode = [NSNumber numberWithInt:[tree st_ino]];
    NSString *existing = nil;
    if ([tree st_nlink] > 1) {
        existing = [theHardlinks objectForKey:inode];
    }
    if (existing != nil) {
        // Link.
        if (link([existing fileSystemRepresentation], [path fileSystemRepresentation]) == -1) {
            int errnum = errno;
            SETNSERROR([self errorDomain], -1, @"link(%@,%@): %s", existing, path, strerror(errnum));
            HSLogError(@"link() failed");
            return NO;
        }
    } else {
        BOOL isDir = NO;
        if ([[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir]) {
            if (!isDir) {
                if (![[NSFileManager defaultManager] removeItemAtPath:path error:error]) {
                    return NO;
                }
            }
        } else {
            if (![[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:error]) {
                return NO;
            }
        }
        [theHardlinks setObject:path forKey:inode];
    }
    if ([theRestorer useTargetUIDAndGID]) {
        HSLogDebug(@"use restorer %@ target UID %d and GID %d", theRestorer, [theRestorer targetUID], [theRestorer targetGID]);
        if (![FileAttributes applyUID:[theRestorer targetUID] gid:[theRestorer targetGID] toPath:path error:error]) {
            return NO;
        }
    } else {
        HSLogDebug(@"use tree %@ UID %d and GID %d", tree, [tree uid], [tree gid]);
        if (![FileAttributes applyUID:[tree uid] gid:[tree gid] toPath:path error:error]) {
            return NO;
        }
    }
    return YES;
}
- (BOOL)restoreNodeWithHardlinks:(NSMutableDictionary *)theHardlinks restorer:(id <Restorer>)theRestorer error:(NSError **)error {
    NSNumber *inode = [NSNumber numberWithInt:[node st_ino]];
    NSString *existing = nil;
    if ([node st_nlink] > 1) {
        existing = [theHardlinks objectForKey:inode];
    }
    if (existing != nil) {
        // Link.
        if (link([existing fileSystemRepresentation], [path fileSystemRepresentation]) == -1) {
            int errnum = errno;
            SETNSERROR([self errorDomain], -1, @"link(%@,%@): %s", existing, path, strerror(errnum));
            HSLogError(@"link() failed");
            return NO;
        }
    } else {
        struct stat st;
        if (lstat([path fileSystemRepresentation], &st) == -1) {
            int errnum = errno;
            if (errnum != ENOENT) {
                SETNSERROR(@"UnixErrorDomain", errnum, @"lstat(%@): %s", path, strerror(errnum));
                return NO;
            }
        } else {
            BOOL shouldSkip = [theRestorer shouldSkipFile:path];
            if (!S_ISREG(st.st_mode) || !shouldSkip) {
                HSLogDetail(@"removing %@ because it's in the way", path);
                if (![[NSFileManager defaultManager] removeItemAtPath:path error:error]) {
                    HSLogError(@"error removing %@", path);
                    return NO;
                }
            }
        }
        int mode = [node mode];
        if (S_ISFIFO(mode)) {
            if (mkfifo([path fileSystemRepresentation], mode) == -1) {
                int errnum = errno;
                SETNSERROR([self errorDomain], errnum, @"mkfifo(%@): %s", path, strerror(errnum));
                return NO;
            }
            if (![self applyNodeWithRestorer:theRestorer error:error]) {
                HSLogError(@"applyNode error");
                return NO;
            }
        } else if (S_ISSOCK(mode)) {
            // Skip socket -- restoring it doesn't make any sense.
        } else {
            if (![self createFile:node restorer:theRestorer error:error]) {
                return NO;
            }
            // We call this once here in case it's not a regular file. We also call it after the last blob in restoreFileDataWithRestorer so the metadata are set after the last file blob.
            if (![self applyNodeWithRestorer:theRestorer error:error]) {
                return NO;
            }
        }
        [theHardlinks setObject:path forKey:inode];
    }
    return YES;
}
- (BOOL)applyTreeWithHardlinks:(NSMutableDictionary *)theHardlinks restorer:(id <Restorer>)theRestorer error:(NSError **)error {
    // Make sure all items are available for download.
    if ([tree xattrsBlobKey] != nil) {
        NSNumber *available = [theRestorer isObjectAvailableForBlobKey:[tree xattrsBlobKey] error:error];
        if (available == nil) {
            return NO;
        }
        if (![available boolValue]) {
            SETNSERROR([self errorDomain], ERROR_GLACIER_OBJECT_NOT_AVAILABLE, @"%@ not available", [tree xattrsBlobKey]);
            return NO;
        }
    }
    if ([tree aclBlobKey] != nil) {
        NSNumber *available = [theRestorer isObjectAvailableForBlobKey:[tree aclBlobKey] error:error];
        if (available == nil) {
            return NO;
        }
        if (![available boolValue]) {
            SETNSERROR([self errorDomain], ERROR_GLACIER_OBJECT_NOT_AVAILABLE, @"%@ not available", [tree aclBlobKey]);
            return NO;
        }
    }
    
    
    if ([tree xattrsBlobKey] != nil && ![self applyXAttrsBlobKey:[tree xattrsBlobKey] restorer:theRestorer error:error]) {
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
    
    if (![FileAttributes applyFinderFlags:[tree finderFlags] to:&fsRef isDirectory:YES error:error]
        || ![FileAttributes applyExtendedFinderFlags:[tree extendedFinderFlags] to:&fsRef isDirectory:YES error:error]) {
        return NO;
    }
    if (![FileAttributes applyMode:[tree mode] toPath:path isDirectory:YES error:error]) {
        return NO;
    }
    if (!S_ISLNK([tree mode]) && [tree treeVersion] >= 7 && ![FileAttributes applyMTimeSec:tree.mtime_sec mTimeNSec:tree.mtime_nsec toPath:path error:error]) {
        return NO;
    }
    if (([tree treeVersion] >= 7) && ![FileAttributes applyCreateTimeSec:tree.createTime_sec createTimeNSec:tree.createTime_nsec to:&fsRef error:error]) {
        return NO;
    }
    if (![FileAttributes applyFlags:(unsigned long)[tree flags] toPath:path error:error]) {
        return NO;
    }
    if (([tree uid] < 500 && [tree gid] < 500) || ![theRestorer useTargetUIDAndGID]) {
        if ([tree aclBlobKey] != nil && ![self applyACLBlobKey:[tree aclBlobKey] restorer:theRestorer error:error]) {
            return NO;
        }
    }
    return YES;
}
- (BOOL)applyXAttrsBlobKey:(BlobKey *)xattrsBlobKey restorer:(id <Restorer>)theRestorer error:(NSError **)error {
    NSAssert(xattrsBlobKey != nil, @"xattrsBlobKey may not be nil");
    NSData *xattrsData = [theRestorer dataForBlobKey:xattrsBlobKey error:error];
    if (xattrsData == nil) {
        return NO;
    }
    if ([xattrsBlobKey compressed]) {
        xattrsData = [xattrsData gzipInflate:error];
        if (xattrsData == nil) {
            return NO;
        }
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
- (BOOL)applyACLBlobKey:(BlobKey *)theACLBlobKey restorer:(id <Restorer>)theRestorer error:(NSError **)error {
    NSAssert(theACLBlobKey != nil, @"theACLBlobKey may not be nil");
    NSData *data = [theRestorer dataForBlobKey:theACLBlobKey error:error];
    if (data == nil) {
        return NO;
    }
    if ([theACLBlobKey compressed]) {
        data = [data gzipInflate:error];
        if (data == nil) {
            return NO;
        }
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
- (BOOL)createFile:(Node *)theNode restorer:(id <Restorer>)theRestorer error:(NSError **)error {
    // Make sure all items are available for download.
    if ([theNode xattrsBlobKey] != nil) {
        NSNumber *available = [theRestorer isObjectAvailableForBlobKey:[theNode xattrsBlobKey] error:error];
        if (available == nil) {
            return NO;
        }
        if (![available boolValue]) {
            SETNSERROR([self errorDomain], ERROR_GLACIER_OBJECT_NOT_AVAILABLE, @"xattrs blob %@ not available", [theNode xattrsBlobKey]);
            return NO;
        }
    }
    if ([theNode aclBlobKey] != nil) {
        NSNumber *available = [theRestorer isObjectAvailableForBlobKey:[theNode aclBlobKey] error:error];
        if (available == nil) {
            return NO;
        }
        if (![available boolValue]) {
            SETNSERROR([self errorDomain], ERROR_GLACIER_OBJECT_NOT_AVAILABLE, @"acl blob %@ not available", [theNode aclBlobKey]);
            return NO;
        }
    }
    
    BOOL shouldSkipFile = [theRestorer shouldSkipFile:path];
    BOOL shouldRestoreUIDAndGID = YES;
    
    if (![[NSFileManager defaultManager] ensureParentPathExistsForPath:path targetUID:[theRestorer targetUID] targetGID:[theRestorer targetGID] error:error]) {
        HSLogError(@"error ensuring path %@ exists", path);
        return NO;
    }
    if (!shouldSkipFile) {
        if ([[NSFileManager defaultManager] fileExistsAtPath:path] && ![[NSFileManager defaultManager] removeItemAtPath:path error:error]) {
            HSLogError(@"error removing existing file %@", path);
            return NO;
        }
        
        HSLogTrace(@"%qu bytes -> %@", [node uncompressedDataSize], path);
        if (S_ISLNK([node mode])) {
            NSMutableData *data = [NSMutableData data];
            for (BlobKey *dataBlobKey in [node dataBlobKeys]) {
                NSData *blobData = [theRestorer dataForBlobKey:dataBlobKey error:error];
                if (blobData == nil) {
                    HSLogError(@"error getting data for %@", dataBlobKey);
                    return NO;
                }
                if ([dataBlobKey compressed]) {
                    blobData = [blobData gzipInflate:error];
                    if (blobData == nil) {
                        return NO;
                    }
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
        } else if ([node uncompressedDataSize] > 0) {
            fileOutputStream = [[FileOutputStream alloc] initWithPath:path append:NO];
            if ([[node dataBlobKeys] count] > 0) {
                if (![self restoreFileDataWithRestorer:theRestorer error:error]) {
                    return NO;
                }
                shouldRestoreUIDAndGID = NO;
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
    } else {
        HSLogDetail(@"skipped restoring %@", path);
    }
    if (shouldRestoreUIDAndGID) {
        if ([theRestorer useTargetUIDAndGID]) {
            HSLogDebug(@"use restorer %@ target UID %d and GID %d", theRestorer, [theRestorer targetUID], [theRestorer targetGID]);
            if (![FileAttributes applyUID:[theRestorer targetUID] gid:[theRestorer targetGID] toPath:path error:error]) {
                return NO;
            }
        } else {
            HSLogDebug(@"use node %@ UID %d and GID %d", node, [node uid], [node gid]);
            if (![FileAttributes applyUID:[node uid] gid:[node gid] toPath:path error:error]) {
                return NO;
            }
        }
    }

    return YES;
}
- (BOOL)restoreFileDataWithRestorer:(id <Restorer>)theRestorer error:(NSError **)error {
    NSError *myError = nil;
    if (![self doRestoreFileDataWithRestorer:theRestorer error:&myError]) {
        SETERRORFROMMYERROR;
        if ([myError isErrorWithDomain:[self errorDomain] code:ERROR_GLACIER_OBJECT_NOT_AVAILABLE]) {
            HSLogDebug(@"object #%ld not available yet", (unsigned long)dataBlobKeyIndex);
        } else {
            // An error occurred. Stop continuing to restore this file.
            dataBlobKeyIndex = [[node dataBlobKeys] count];
            errorOccurred = YES;
        }
        return NO;
    }
    return YES;
}
- (BOOL)doRestoreFileDataWithRestorer:(id <Restorer>)theRestorer error:(NSError **)error {
    BlobKey *theBlobKey = [[node dataBlobKeys] objectAtIndex:dataBlobKeyIndex];
    NSNumber *available = [theRestorer isObjectAvailableForBlobKey:theBlobKey error:error];
    if (available == nil) {
        return NO;
    }
    if (![available boolValue]) {
        SETNSERROR([self errorDomain], ERROR_GLACIER_OBJECT_NOT_AVAILABLE, @"acl blob %@ not available", theBlobKey);
        return NO;
    }
    NSData *blobData = [theRestorer dataForBlobKey:theBlobKey error:error];
    if (blobData == nil) {
        NSError *myError = nil;
        if (![[NSFileManager defaultManager] removeItemAtPath:path error:&myError]) {
            HSLogError(@"error deleting incomplete file %@: %@", path, [myError localizedDescription]);
        } else {
            HSLogError(@"deleted incomplete file %@", path);
        }
        return NO;
    }
    if ([theBlobKey compressed]) {
        blobData = [blobData gzipInflate:error];
        if (blobData == nil) {
            return NO;
            NSError *myError = nil;
            if (![[NSFileManager defaultManager] removeItemAtPath:path error:&myError]) {
                HSLogError(@"error deleting incomplete file %@: %@", path, [myError localizedDescription]);
            } else {
                HSLogError(@"deleted incomplete file %@", path);
            }
        }
    }

    BufferedOutputStream *bos = [[BufferedOutputStream alloc] initWithUnderlyingOutputStream:fileOutputStream];
    NSError *myError = nil;
    BOOL ret = [bos writeFully:[blobData bytes] length:[blobData length] error:&myError] && [bos flush:&myError];
    [bos release];
    if (!ret) {
        HSLogError(@"error appending data to %@: %@", path, myError);
        SETERRORFROMMYERROR;
        if (![[NSFileManager defaultManager] removeItemAtPath:path error:&myError]) {
            HSLogError(@"error deleting incomplete file %@: %@", path, [myError localizedDescription]);
        } else {
            HSLogError(@"deleted incomplete file %@", path);
        }
        return NO;
    }
    dataBlobKeyIndex++;
    HSLogDebug(@"appended blob %ld of %ld to %@", (unsigned long)dataBlobKeyIndex, (unsigned long)[[node dataBlobKeys] count], path);
    
    if (dataBlobKeyIndex >= [[node dataBlobKeys] count]) {
        if ([theRestorer useTargetUIDAndGID]) {
            HSLogDebug(@"use restorer %@ target UID %d and GID %d", theRestorer, [theRestorer targetUID], [theRestorer targetGID]);
            if (![FileAttributes applyUID:[theRestorer targetUID] gid:[theRestorer targetGID] toPath:path error:error]) {
                return NO;
            }
        } else {
            HSLogDebug(@"use node %@ UID %d and GID %d", node, [node uid], [node gid]);
            if (![FileAttributes applyUID:[node uid] gid:[node gid] toPath:path error:error]) {
                return NO;
            }
        }
        if (![self applyNodeWithRestorer:theRestorer error:error]) {
            return NO;
        }
    }
    return YES;
}
- (BOOL)applyNodeWithRestorer:(id <Restorer>)theRestorer error:(NSError **)error {
    NSError *xattrsError = nil;
    if ([node xattrsBlobKey] != nil && ![self applyXAttrsBlobKey:[node xattrsBlobKey] restorer:theRestorer error:&xattrsError]) {
        HSLogError(@"failed to apply xattrs %@ to %@: %@", [node xattrsBlobKey], path, xattrsError);
    }
    if (([node uid] < 500 && [node gid] < 500) || ![theRestorer useTargetUIDAndGID]) {
        NSError *aclError = nil;
        if ([node aclBlobKey] != nil && ![self applyACLBlobKey:[node aclBlobKey] restorer:theRestorer error:&aclError]) {
            HSLogError(@"failed to apply acl %@ to %@: %@", [node aclBlobKey], path, aclError);
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
    if (oss == bdNamErr) {
        HSLogInfo(@"skipping applying some metadata for %@: %@", path, [OSStatusDescription descriptionForOSStatus:oss]);
    } else if (oss != noErr) {
        SETNSERROR(@"MacFilesErrorDomain", oss, @"error making FSRef for %@: %@", path, [OSStatusDescription descriptionForOSStatus:oss]);
        return NO;
    } else {
        if (!S_ISFIFO([node mode])) {
            FileAttributes *fa = [[[FileAttributes alloc] initWithPath:path stat:&st error:error] autorelease];
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
    if (!S_ISLNK([node mode]) && [node treeVersion] >= 7 && ![FileAttributes applyMTimeSec:node.mtime_sec mTimeNSec:node.mtime_nsec toPath:path error:error]) {
        return NO;
    }
    if (!S_ISFIFO([node mode])) {
        if (st.st_flags != [node flags] && ![FileAttributes applyFlags:(unsigned long)[node flags] toPath:path error:error]) {
            return NO;
        }
    }
    return YES;
}
- (NSArray *)nextItemsForTreeWithRepo:(Repo *)theRepo error:(NSError **)error {
    NSMutableArray *nextItems = [NSMutableArray array];
    NSAutoreleasePool *pool = nil;
    for (NSString *childNodeName in [tree childNodeNames]) {
        [pool drain];
        pool = [[NSAutoreleasePool alloc] init];
        Node *childNode = [tree childNodeWithName:childNodeName];
        NSString *childPath = [path stringByAppendingPathComponent:childNodeName];
        if ([childNode isTree]) {
            Tree *childTree = [theRepo treeForBlobKey:[childNode treeBlobKey] error:error];
            if (childTree == nil) {
                nextItems = nil;
                break;
            }
            RestoreItem *childRestoreItem = [[[RestoreItem alloc] initWithPath:childPath tree:childTree] autorelease];
            [nextItems addObject:childRestoreItem];
        } else {
            RestoreItem *childRestoreItem = [[[RestoreItem alloc] initWithPath:childPath tree:tree node:childNode] autorelease];
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
    RestoreItem *treeRestoreItem = [[[RestoreItem alloc] initApplyItemWithTree:tree path:path] autorelease];
    [nextItems addObject:treeRestoreItem];
    return nextItems;
}


#pragma mark NSObject
- (NSString *)description {
    return [NSString stringWithFormat:@"<RestoreItem %@>", path];
}
@end
