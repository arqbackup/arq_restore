//
//  Repo.h
//  Arq
//
//  Created by Stefan Reitshamer on 12/30/13.
//  Copyright (c) 2013 Stefan Reitshamer. All rights reserved.
//

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
