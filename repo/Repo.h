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


@class Bucket;
@protocol Fark;
@class BlobKey;
@class Commit;
@class Tree;
@class CryptoKey;
@class PackSet;
@class Repo;
@class TargetObjectSet;
@class PackId;
@protocol DataTransferDelegate;
@protocol TargetConnectionDelegate;


@protocol RepoDelegate <NSObject>
- (void)repo:(Repo *)theRepo headBlobKeyDidChangeFrom:(BlobKey *)fromBlobKey to:(BlobKey *)toBlobKey rewrite:(BOOL)rewrite;
- (void)headBlobKeyWasDeletedForRepo:(Repo *)theRepo;
@end

@interface Repo : NSObject {
    Bucket *bucket;
    uid_t targetUID;
    gid_t targetGID;
    CryptoKey *cryptoKey;
    CryptoKey *stretchedCryptoKey;
    id <Fark> fark;
    PackSet *treesPackSet;
    PackSet *blobsPackSet;
    id <TargetConnectionDelegate> targetConnectionDelegate;
    id <RepoDelegate> repoDelegate;
}

- (id)initWithBucket:(Bucket *)theBucket
  encryptionPassword:(NSString *)theEncryptionPassword
           targetUID:(uid_t)theTargetUID
           targetGID:(gid_t)theTargetGID
loadExistingMutablePackFiles:(BOOL)theLoadExistingMutablePackFiles
targetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD
        repoDelegate:(id <RepoDelegate>)theRepoDelegate
               error:(NSError **)error;

- (NSString *)errorDomain;

- (Bucket *)bucket;
- (BlobKey *)headBlobKey:(NSError **)error;
- (NSArray *)allCommitBlobKeys:(NSError **)error;
- (Commit *)commitForBlobKey:(BlobKey *)treeBlobKey error:(NSError **)error;
- (Commit *)commitForBlobKey:(BlobKey *)treeBlobKey dataSize:(unsigned long long *)dataSize error:(NSError **)error;
- (Tree *)treeForBlobKey:(BlobKey *)treeBlobKey error:(NSError **)error;
- (Tree *)treeForBlobKey:(BlobKey *)treeBlobKey dataSize:(unsigned long long *)dataSize error:(NSError **)error;
- (NSNumber *)containsBlobForBlobKey:(BlobKey *)theBlobKey error:(NSError **)error;
- (NSNumber *)containsBlobForBlobKey:(BlobKey *)theBlobKey dataSize:(unsigned long long *)dataSize error:(NSError **)error;
- (NSNumber *)containsBlobForBlobKey:(BlobKey *)theBlobKey dataSize:(unsigned long long *)dataSize forceTargetCheck:(BOOL)forceTargetCheck error:(NSError **)error;

- (NSNumber *)isObjectDownloadableForBlobKey:(BlobKey *)theBlobKey error:(NSError **)error;
- (BOOL)restoreObjectForBlobKey:(BlobKey *)theBlobKey forDays:(NSUInteger)theDays alreadyRestoredOrRestoring:(BOOL *)alreadyRestoredOrRestoring error:(NSError **)error;
- (NSData *)dataForBlobKey:(BlobKey *)theBlobKey error:(NSError **)error;

- (NSData *)decryptData:(NSData *)theData error:(NSError **)error;
- (NSData *)encryptData:(NSData *)theData error:(NSError **)error;

- (BOOL)addSHA1sForCommitBlobKey:(BlobKey *)commitBlobKey toSet:(NSMutableSet *)theSet error:(NSError **)error;

@end
