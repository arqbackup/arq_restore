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



@class Bucket;
#import "BlobKey.h"
@class Commit;
@class Tree;
@class SynchronousPackSet;
@class Repo;
@class PackId;
@protocol DataTransferDelegate;
@protocol TargetConnectionDelegate;
@class ObjectEncryptor;
#import "Fark.h"
#import "PackSet.h"


@protocol RepoDelegate <NSObject>
- (void)headBlobKeyDidChangeForTargetUUID:(NSString *)theTargetUUID computerUUID:(NSString *)theComputerUUID bucketUUID:(NSString *)theBucketUUID from:(BlobKey *)fromBlobKey to:(BlobKey *)toBlobKey rewrite:(BOOL)rewrite;
- (void)headBlobKeyWasDeletedForTargetUUID:(NSString *)theTargetUUID computerUUID:(NSString *)theComputerUUID bucketUUID:(NSString *)theBucketUUID;
@end

@protocol RepoActivityListener <NSObject>
- (void)repoActivity:(NSString *)theActivity;
- (void)repoActivityDidFinish;
@end


@interface Repo : NSObject <PackSetActivityListener> {
    Bucket *bucket;
    ObjectEncryptor *encryptor;
    Fark *fark;
    SynchronousPackSet *treesPackSet;
    SynchronousPackSet *blobsPackSet;
    id <TargetConnectionDelegate> targetConnectionDelegate;
    id <RepoDelegate> repoDelegate;
    id <RepoActivityListener> repoActivityListener;
    NSLock *compressEncryptLock;
}

+ (BlobKeyCompressionType)defaultBlobKeyCompressionType;

- (id)initWithBucket:(Bucket *)theBucket
  encryptionPassword:(NSString *)theEncryptionPassword
targetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD
        repoDelegate:(id <RepoDelegate>)theRepoDelegate
    activityListener:(id <RepoActivityListener>)theActivityListener
               error:(NSError **)error;

- (NSString *)errorDomain;

- (int)objectEncryptorVersion;
- (id <TargetConnectionDelegate>)targetConnectionDelegate;
- (Bucket *)bucket;
- (BlobKey *)headBlobKey:(NSError **)error;
- (NSArray *)allCommitBlobKeys:(NSError **)error;
- (Commit *)commitForBlobKey:(BlobKey *)treeBlobKey error:(NSError **)error;
- (Commit *)commitForBlobKey:(BlobKey *)treeBlobKey dataSize:(unsigned long long *)dataSize error:(NSError **)error;
- (Tree *)treeForBlobKey:(BlobKey *)treeBlobKey error:(NSError **)error;
- (Tree *)treeForBlobKey:(BlobKey *)treeBlobKey dataSize:(unsigned long long *)dataSize error:(NSError **)error;
- (NSNumber *)containsBlobsInCacheForBlobKeys:(NSArray *)theBlobKeys error:(NSError **)error;
- (NSNumber *)containsBlobInCacheForBlobKey:(BlobKey *)theBlobKey error:(NSError **)error;
- (NSNumber *)sizeOfBlobInCacheForBlobKey:(BlobKey *)theBlobKey error:(NSError **)error;

- (NSNumber *)isObjectDownloadableForBlobKey:(BlobKey *)theBlobKey error:(NSError **)error;
- (BOOL)restoreObjectForBlobKey:(BlobKey *)theBlobKey forDays:(NSUInteger)theDays tier:(int)theGlacierRetrievalTier alreadyRestoredOrRestoring:(BOOL *)alreadyRestoredOrRestoring error:(NSError **)error;
- (NSData *)dataForBlobKey:(BlobKey *)theBlobKey error:(NSError **)error;

- (BOOL)setHeadBlobKey:(BlobKey *)theBlobKey rewrite:(BOOL)rewrite error:(NSError **)error;
- (BOOL)deleteHeadBlobKey:(NSError **)error;

- (NSData *)encryptV1Data:(NSData *)theData error:(NSError **)error;
- (BlobKey *)blobKeyForV1Data:(NSData *)theData compressionType:(BlobKeyCompressionType)theCompressionType error:(NSError **)error;
- (BlobKey *)blobKeyForV2Data:(NSData *)theFileData compressionType:(BlobKeyCompressionType)theCompressionType error:(NSError **)error;

- (NSData *)decryptData:(NSData *)theData error:(NSError **)error;

- (BOOL)deleteBlobForBlobKey:(BlobKey *)theBlobKey error:(NSError **)error;


@end
