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



#import "StorageType.h"
#import "Restorer.h"
#import "TargetConnection.h"
#import "Repo.h"
@protocol StandardRestorerDelegate;
@class StandardRestorerParamSet;
@class Repo;
@class Commit;
@class Tree;
@class BlobKey;
@class Node;
@class StandardRestoreItem;
@class StandardRestorerDelegateMux;


@interface StandardRestorer : NSObject <TargetConnectionDelegate, RepoActivityListener> {
    StandardRestorerParamSet *paramSet;
    StandardRestorerDelegateMux *srdMux;
    
    NSMutableDictionary *hardlinkPathsByInode;

    Repo *repo;
    Commit *commit;
    NSString *commitDescription;
    Tree *rootTree;
    Node *nodeToRestore;

    NSMutableArray *standardRestoreItems;
    
    dispatch_semaphore_t workerThreadSemaphore;
    NSLock *lock;
    
    unsigned long long bytesTransferred;
    unsigned long long totalBytesToTransfer;
    
    unsigned long long writtenToCurrentFile;
    
    BOOL cancelRequested;
}
- (id)initWithParamSet:(StandardRestorerParamSet *)theParamSet
              delegate:(id <StandardRestorerDelegate>)theDelegate;


- (NSString *)errorDomain;

- (StandardRestoreItem *)nextItem;
- (NSString *)hardlinkedPathForInode:(int)theInode;
- (void)setHardlinkedPath:(NSString *)thePath forInode:(int)theInode;
- (Tree *)treeForBlobKey:(BlobKey *)theBlobKey error:(NSError **)error;
- (NSData *)dataForBlobKey:(BlobKey *)theBlobKey error:(NSError **)error;
- (BOOL)useTargetUIDAndGID;
- (uid_t)targetUID;
- (gid_t)targetGID;
- (void)workerDidFinish;
- (BOOL)addToFileBytesRestored:(unsigned long long)length error:(NSError **)error;
- (BOOL)addToTotalFileBytesToRestore:(unsigned long long)length error:(NSError **)error;
- (BOOL)deleteBlobForBlobKey:(BlobKey *)theBlobKey error:(NSError **)error;
@end
