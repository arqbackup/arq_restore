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



#import "StandardRestorer.h"
#import "StandardRestorerDelegate.h"
#import "Repo.h"
#import "Tree.h"
#import "Node.h"
#import "FileOutputStream.h"
#import "Commit.h"
#import "BlobKey.h"
#import "NSFileManager_extra.h"
#import "BufferedOutputStream.h"
#import "OSStatusDescription.h"
#import "FileAttributes.h"
#import "FileACL.h"
#import "DataInputStream.h"
#import "XAttrSet.h"
#import "FileInputStream.h"
#import "SHA1Hash.h"
#import "StandardRestorerParamSet.h"
#import "CalculateItem.h"
#import "RestoreItem.h"
#import "UserLibrary_Arq.h"
#import "Bucket.h"
#import "Target.h"
#import "AWSRegion.h"
#import "StandardRestoreWorker.h"
#import "StandardRestorerDelegateMux.h"
#import "StandardRestoreItem.h"


#define DEFAULT_NUM_WORKER_THREADS (4)


@implementation StandardRestorer
- (id)initWithParamSet:(StandardRestorerParamSet *)theParamSet delegate:(id<StandardRestorerDelegate>)theDelegate {
    if (self = [super init]) {
        paramSet = [theParamSet retain];
        srdMux = [[StandardRestorerDelegateMux alloc] initWithStandardRestorerDelegate:theDelegate];
        
        hardlinkPathsByInode = [[NSMutableDictionary alloc] init];
        
        standardRestoreItems = [[NSMutableArray alloc] init];
        
        workerThreadSemaphore = dispatch_semaphore_create(0);
        lock = [[NSLock alloc] init];
        [lock setName:@"StandardRestorer lock"];
        
        [self run];
    }
    return self;
}
- (void)dealloc {
    [paramSet release];
    [srdMux release];
    
    [hardlinkPathsByInode release];
    
    [repo release];
    [commit release];
    [commitDescription release];
    [rootTree release];
    [nodeToRestore release];
    
    [standardRestoreItems release];
    
    dispatch_release(workerThreadSemaphore);
    [lock release];
    
    [super dealloc];
}

- (NSString *)errorDomain {
    return @"StandardRestorerErrorDomain";
}

- (StandardRestoreItem *)nextItem {
    [lock lock];
    StandardRestoreItem *ret = nil;
    if (!cancelRequested && [standardRestoreItems count] > 0) {
        ret = [[[standardRestoreItems lastObject] retain] autorelease];
        [standardRestoreItems removeLastObject];
        
        NSError *myError = nil;
        NSArray *nextItems = [ret nextItems:&myError];
        if (nextItems == nil) {
            HSLogError(@"failed to load next items for %@: %@", [ret path], myError);
        } else {
            [standardRestoreItems addObjectsFromArray:nextItems];
        }
    }
    [lock unlock];
    if (ret == nil) {
        HSLogDebug(@"no more restore items");
    }
    return ret;
}
- (NSString *)hardlinkedPathForInode:(int)theInode {
    [lock lock];
    NSString *ret = [[[hardlinkPathsByInode objectForKey:[NSNumber numberWithInt:theInode]] copy] autorelease];
    [lock unlock];
    return ret;
}
- (void)setHardlinkedPath:(NSString *)thePath forInode:(int)theInode {
    if (theInode != 0) {
        [lock lock];
        [hardlinkPathsByInode setObject:thePath forKey:[NSNumber numberWithInt:theInode]];
        [lock unlock];
    }
}
- (Tree *)treeForBlobKey:(BlobKey *)theBlobKey error:(NSError **)error {
    return [repo treeForBlobKey:theBlobKey error:error];
}
- (NSData *)dataForBlobKey:(BlobKey *)theBlobKey error:(NSError **)error {
    NSData *ret = [repo dataForBlobKey:theBlobKey error:error];
    if (ret == nil) {
        return nil;
    }
    return ret;
}
- (BOOL)useTargetUIDAndGID {
    return paramSet.useTargetUIDAndGID;
}
- (uid_t)targetUID {
    return paramSet.targetUID;
}
- (gid_t)targetGID {
    return paramSet.targetGID;
}
- (void)workerDidFinish {
    dispatch_semaphore_signal(workerThreadSemaphore);
}


#pragma mark thread main
- (void)run {
    NSError *myError = nil;
    if (![self run:&myError]) {
        [srdMux standardRestorerDidFail:myError];
    } else {
        [srdMux standardRestorerDidSucceed];
    }
}


#pragma mark TargetConnectionDelegate
- (BOOL)targetConnectionShouldRetryOnTransientError:(NSError **)error {
    if (cancelRequested) {
        SETNSERROR([self errorDomain], ERROR_ABORT_REQUESTED, @"cancel requested");
        return NO;
    }
    return YES;
}


#pragma mark RepoActivityListener
- (void)repoActivity:(NSString *)theActivity {
    if ([srdMux standardRestorerMessageDidChange:[NSString stringWithFormat:@"%@", theActivity]]) {
        cancelRequested = YES;
    }
}
- (void)repoActivityDidFinish {
    NSString *msg = [NSString stringWithFormat:@"Restoring %@ to %@", paramSet.rootItemName, paramSet.destinationPath];
    if (commitDescription != nil) {
        msg = [NSString stringWithFormat:@"Restoring %@ from %@ to %@", paramSet.rootItemName, commitDescription, paramSet.destinationPath];
    }
    if ([srdMux standardRestorerMessageDidChange:msg]) {
        cancelRequested = YES;
    }
}


#pragma mark internal
- (BOOL)run:(NSError **)error {
    if (![self setUp:error]) {
        return NO;
    }

    if (![[NSFileManager defaultManager] ensureParentPathExistsForPath:paramSet.destinationPath targetUID:paramSet.targetUID targetGID:paramSet.targetGID error:error]) {
        return NO;
    }
    
    if ([srdMux standardRestorerMessageDidChange:[NSString stringWithFormat:@"Creating directory structure for %@", paramSet.rootItemName]]) {
        cancelRequested = YES;
        SETNSERROR([self errorDomain], ERROR_ABORT_REQUESTED, @"cancel requested");
        return NO;
    }
    
    if (![self createDirectoryTree:error]) {
        return NO;
    }
    
    if ([srdMux standardRestorerMessageDidChange:[NSString stringWithFormat:@"Restoring %@ from %@ to %@", paramSet.rootItemName, commitDescription, paramSet.destinationPath]]) {
        cancelRequested = YES;
        SETNSERROR([self errorDomain], ERROR_ABORT_REQUESTED, @"cancel requested");
        return NO;
    }
    
    // Create initial StandardRestoreItem:
    StandardRestoreItem *firstItem = nil;
    if (nodeToRestore != nil) {
        firstItem = [[[StandardRestoreItem alloc] initWithStandardRestorer:self path:paramSet.destinationPath tree:rootTree node:nodeToRestore] autorelease];
    } else {
        firstItem = [[[StandardRestoreItem alloc] initWithStandardRestorer:self path:paramSet.destinationPath tree:rootTree] autorelease];
    }
    [standardRestoreItems addObject:firstItem];
    
    NSUInteger numWorkerThreads = DEFAULT_NUM_WORKER_THREADS;
    // Create threads.
    for (NSUInteger i = 0; i < numWorkerThreads; i++) {
        [[[StandardRestoreWorker alloc] initWithStandardRestorer:self standardRestorerDelegate:srdMux] autorelease];
    }
    
    // Wait for restoring to finish.
    for (NSUInteger i = 0; i < numWorkerThreads; i++) {
        dispatch_semaphore_wait(workerThreadSemaphore, DISPATCH_TIME_FOREVER);
    }
    return YES;
}
- (BOOL)setUp:(NSError **)error {
    repo = [[Repo alloc] initWithBucket:paramSet.bucket
                     encryptionPassword:paramSet.encryptionPassword
               targetConnectionDelegate:self
                           repoDelegate:nil
                       activityListener:self
                                  error:error];
    if (repo == nil) {
        return NO;
    }
    if ([srdMux standardRestorerMessageDidChange:[NSString stringWithFormat:@"Caching object list from %@", [[paramSet.bucket target] endpointDisplayName]]]) {
        cancelRequested = YES;
        SETNSERROR([self errorDomain], ERROR_ABORT_REQUESTED, @"cancel requested");
        return NO;
    }
    // Ask for an object, which forces RemoteFS to cache the list of objects, which could take several minutes.
    BlobKey *fakeBlobKey = [[[BlobKey alloc] initWithSHA1:@"0000000000000000000000000000000000000000" storageType:StorageTypeS3 stretchEncryptionKey:YES compressionType:BlobKeyCompressionNone error:NULL] autorelease];
    [repo dataForBlobKey:fakeBlobKey error:error];
    
    commit = [[repo commitForBlobKey:paramSet.commitBlobKey error:error] retain];
    if (commit == nil) {
        return NO;
    }
    NSDateFormatter *dateFormatter = [[[NSDateFormatter alloc] init] autorelease];
    [dateFormatter setDateStyle:NSDateFormatterMediumStyle];
    [dateFormatter setTimeStyle:NSDateFormatterShortStyle];
    commitDescription = [[dateFormatter stringFromDate:[commit creationDate]] retain];
    
    rootTree = [[repo treeForBlobKey:paramSet.treeBlobKey error:error] retain];
    if (rootTree == nil) {
        return NO;
    }
    
    unsigned long long total = 0;
    if (paramSet.nodeName != nil) {
        // Individual file.
        Node *node = [rootTree childNodeWithName:paramSet.nodeName];
        if ([[rootTree childNodeNames] isEqualToArray:[NSArray arrayWithObject:@"."]]) {
            // The single-file case.
            node = [rootTree childNodeWithName:@"."];
        }
        NSAssert(node != nil, @"node may not be nil");
        total = [node uncompressedDataSize];
        nodeToRestore = [node retain];
    } else {
        // Tree.
        total = [rootTree aggregateUncompressedDataSize];
    }
    if (![self addToTotalFileBytesToRestore:total error:error]) {
        return NO;
    }
    
    return YES;
}
- (BOOL)createDirectoryTree:(NSError **)error {
    if (nodeToRestore == nil) {
        if (![self createDirectoriesForTree:rootTree inDirectory:paramSet.destinationPath error:error]) {
            return NO;
        }
    } else {
        if (![[NSFileManager defaultManager] ensureParentPathExistsForPath:paramSet.destinationPath targetUID:paramSet.targetUID targetGID:paramSet.targetGID error:error]) {
            return NO;
        }
    }
    return YES;
}
- (BOOL)createDirectoriesForTree:(Tree *)theTree inDirectory:(NSString *)theDir error:(NSError **)error {
    if (![self createDirectory:theDir tree:theTree error:error]) {
        return NO;
    }
    NSAutoreleasePool *pool = nil;
    BOOL ret = YES;
    for (NSString *childName in [theTree childNodeNames]) {
        [pool drain];
        pool = [[NSAutoreleasePool alloc] init];
        Node *childNode = [theTree childNodeWithName:childName];
        if ([childNode isTree]) {
            NSString *childPath = [theDir stringByAppendingPathComponent:childName];
            Tree *childTree = [repo treeForBlobKey:[childNode treeBlobKey] dataSize:NULL error:error];
            if (childTree == nil) {
                ret = NO;
                break;
            }
            if (![self createDirectoriesForTree:childTree inDirectory:childPath error:error]) {
                ret = NO;
                break;
            }
        }
    }
    if (!ret && error != NULL) {
        [*error retain];
    }
    [pool drain];
    if (!ret && error != NULL) {
        [*error autorelease];
    }
    return YES;
}
- (BOOL)createDirectory:(NSString *)thePath tree:(Tree *)theTree error:(NSError **)error {
    BOOL isDir = NO;
    if ([[NSFileManager defaultManager] fileExistsAtPath:thePath isDirectory:&isDir]) {
        if (!isDir) {
            SETNSERROR([self errorDomain], -1, @"%@ exists and is not a directory", thePath);
            return NO;
        }
    } else {
        NSString *existingDir = [hardlinkPathsByInode objectForKey:[NSNumber numberWithInt:[theTree st_ino]]];
        if (existingDir != nil) {
            // Create hard link to the existing directory:
            if (link([existingDir fileSystemRepresentation], [thePath fileSystemRepresentation]) == -1) {
                int errnum = errno;
                SETNSERROR([self errorDomain], errnum, @"link(%@, %@): %s", existingDir, thePath, strerror(errnum));
                HSLogError(@"link(%@, %@): %s", existingDir, thePath, strerror(errnum));
                return NO;
            }
        } else {
            if (![[NSFileManager defaultManager] createDirectoryAtPath:thePath withIntermediateDirectories:YES attributes:nil error:error]) {
                return NO;
            }
            if ([theTree st_ino] != 0) {
                [hardlinkPathsByInode setObject:thePath forKey:[NSNumber numberWithInt:[theTree st_ino]]];
            }
        }
    }
    return YES;
}

- (BOOL)addToFileBytesRestored:(unsigned long long)length error:(NSError **)error {
    [lock lock];
    bytesTransferred += length;
    BOOL ret = YES;
    if ([srdMux standardRestorerFileBytesRestoredDidChange:[NSNumber numberWithUnsignedLongLong:bytesTransferred]]) {
        cancelRequested = YES;
        SETNSERROR([self errorDomain], ERROR_ABORT_REQUESTED, @"cancel requested");
        ret = NO;
    }
    [lock unlock];
    return ret;
}
- (BOOL)addToTotalFileBytesToRestore:(unsigned long long)length error:(NSError **)error {
    [lock lock];
    totalBytesToTransfer += length;
    BOOL ret = YES;
    if ([srdMux standardRestorerTotalFileBytesToRestoreDidChange:[NSNumber numberWithUnsignedLongLong:totalBytesToTransfer]]) {
        cancelRequested = YES;
        SETNSERROR([self errorDomain], ERROR_ABORT_REQUESTED, @"cancel requested");
        ret = NO;
    }
    [lock unlock];
    return ret;
}
- (BOOL)deleteBlobForBlobKey:(BlobKey *)theBlobKey error:(NSError **)error {
    return [repo deleteBlobForBlobKey:theBlobKey error:error];
}
@end
