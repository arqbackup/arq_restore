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



#import <CommonCrypto/CommonDigest.h>
#import "Repo.h"
#import "Fark.h"
#import "CryptoKey.h"
#import "Bucket.h"
#import "BlobKey.h"
#import "DataInputStream.h"
#import "BufferedInputStream.h"
#import "Target.h"
#import "Commit.h"
#import "Tree.h"
#import "PackSet.h"
#import "NSData-Compress.h"
#import "DictNode.h"
#import "SHA1Hash.h"
#import "Node.h"
#import "CommitList.h"
#import "ObjectEncryptor.h"
#import "SynchronousPackSet.h"
#import "MD5Hash.h"
#import "PackIndexEntry.h"
#import "PackId.h"
#import "StorageType.h"


#define MAX_CONSISTENCY_TRIES (20)
#define ENCRYPTED_OBJECT_HEADER_LEN (116)
#define REVALIDATE_INTERVAL_DAYS (180)


@implementation Repo
+ (BlobKeyCompressionType)defaultBlobKeyCompressionType {
    return BlobKeyCompressionLZ4;
}


- (id)initWithBucket:(Bucket *)theBucket
  encryptionPassword:(NSString *)theEncryptionPassword
targetConnectionDelegate:(id<TargetConnectionDelegate>)theTCD
        repoDelegate:(id<RepoDelegate>)theRepoDelegate
    activityListener:(id <RepoActivityListener>)theActivityListener
               error:(NSError **)error {
    if (self = [super init]) {
        bucket = [theBucket retain];
        targetConnectionDelegate = theTCD;
        repoDelegate = theRepoDelegate;
        repoActivityListener = theActivityListener;
        encryptor = [[ObjectEncryptor alloc] initWithTarget:[theBucket target]
                                               computerUUID:[theBucket computerUUID]
                                         encryptionPassword:theEncryptionPassword
                                   targetConnectionDelegate:targetConnectionDelegate
                                                      error:error];
        if (encryptor == nil) {
            [self release];
            return nil;
        }
        
        fark = [[Fark alloc] initWithTarget:[theBucket target]
                               computerUUID:[theBucket computerUUID]
                   targetConnectionDelegate:theTCD
                                      error:error];
        if (fark == nil) {
            [self release];
            return nil;
        }
        treesPackSet = [[SynchronousPackSet alloc] initWithFark:fark
                                                    storageType:StorageTypeS3
                                                    packSetName:[[bucket bucketUUID] stringByAppendingString:@"-trees"]
                                               cachePackFilesToDisk:YES
                                               activityListener:self
                                                          error:error];
        if (treesPackSet == nil) {
            [self release];
            return nil;
        }
        
        // For StorageTypeGlacier Buckets, use StorageTypeS3Glacier going forward.
        StorageType convertedStorageType = ([bucket storageType] == StorageTypeGlacier) ? StorageTypeS3Glacier : [bucket storageType];
        blobsPackSet = [[SynchronousPackSet alloc] initWithFark:fark
                                                    storageType:convertedStorageType
                                                    packSetName:[[bucket bucketUUID] stringByAppendingString:@"-blobs"]
                                               cachePackFilesToDisk:NO
                                               activityListener:self
                                                          error:error];
        if (blobsPackSet == nil) {
            [self release];
            return nil;
        }
        
        compressEncryptLock = [[NSLock alloc] init];
        [compressEncryptLock setName:@"Repo Compress Encrypt lock"];
    }
    return self;
}
- (void)dealloc {
    [bucket release];
    [fark release];
    [treesPackSet release];
    [blobsPackSet release];
    [compressEncryptLock release];
    [super dealloc];
}

- (NSString *)errorDomain {
    return @"RepoErrorDomain";
}
- (int)objectEncryptorVersion {
    return [encryptor encryptionVersion];
}
- (id <TargetConnectionDelegate>)targetConnectionDelegate {
    return targetConnectionDelegate;
}
- (Bucket *)bucket {
    return bucket;
}
- (BlobKey *)headBlobKey:(NSError **)error {
    NSError *myError = nil;
    BlobKey *ret = [fark headBlobKeyForBucketUUID:[bucket bucketUUID] error:&myError];
    if (ret == nil) {
        SETERRORFROMMYERROR;
        if ([myError isErrorWithDomain:[fark errorDomain] code:ERROR_NOT_FOUND]) {
            SETNSERROR([self errorDomain], ERROR_NOT_FOUND, @"head blob key not found for bucket %@", [bucket bucketUUID]);
        }
    }
    return ret;
}
- (NSArray *)allCommitBlobKeys:(NSError **)error {
    NSError *myError = nil;
    BlobKey *commitBlobKey = [self headBlobKey:&myError];
    if (commitBlobKey == nil && ![myError isErrorWithDomain:[self errorDomain] code:ERROR_NOT_FOUND]) {
        if (error != NULL) {
            *error = myError;
        }
        return nil;
    }
    NSMutableArray *commitBlobKeys = [NSMutableArray array];
    while (commitBlobKey != nil) {
        [commitBlobKeys addObject:commitBlobKey];
        Commit *commit = [self commitForBlobKey:commitBlobKey error:error];
        if (commit == nil) {
            return nil;
        }
        commitBlobKey = [commit parentCommitBlobKey];
    }
    return commitBlobKeys;
}
- (Commit *)commitForBlobKey:(BlobKey *)commitBlobKey error:(NSError **)error {
    return [self commitForBlobKey:commitBlobKey dataSize:NULL error:error];
}
- (Commit *)commitForBlobKey:(BlobKey *)commitBlobKey dataSize:(unsigned long long *)dataSize error:(NSError **)error {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    if (error != NULL) {
        *error = nil;
    }
    Commit *ret = [self doCommitForBlobKey:commitBlobKey dataSize:dataSize error:error];
    [ret retain];
    if (!ret && error != NULL) {
        [*error retain];
    }
    [pool drain];
    [ret autorelease];
    if (!ret && error != NULL) {
        [*error autorelease];
    }
    return ret;
}
- (Tree *)treeForBlobKey:(BlobKey *)blobKey error:(NSError **)error {
    return [self treeForBlobKey:blobKey dataSize:NULL error:error];
}
- (Tree *)treeForBlobKey:(BlobKey *)treeBlobKey dataSize:(unsigned long long *)dataSize error:(NSError **)error {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    if (error != NULL) {
        *error = nil;
    }
    Tree *ret = [self doTreeForBlobKey:treeBlobKey dataSize:dataSize error:error];
    [ret retain];
    if (!ret && error != NULL) {
        [*error retain];
    }
    [pool drain];
    [ret autorelease];
    if (!ret && error != NULL) {
        [*error autorelease];
    }
    return ret;
}
- (NSNumber *)containsBlobsInCacheForBlobKeys:(NSArray *)theBlobKeys error:(NSError **)error {
    for (BlobKey *blobKey in theBlobKeys) {
        NSNumber *contains = [self containsBlobInCacheForBlobKey:blobKey error:error];
        if (contains == nil) {
            return nil;
        }
        if (![contains boolValue]) {
            return contains;
        }
    }
    return [NSNumber numberWithBool:YES];
}
- (NSNumber *)containsBlobInCacheForBlobKey:(BlobKey *)theBlobKey error:(NSError **)error {
    BOOL isPacked = NO;
    return [self containsBlobInCacheForBlobKey:theBlobKey isPacked:&isPacked error:error];
}
- (NSNumber *)containsBlobInCacheForBlobKey:(BlobKey *)theBlobKey isPacked:(BOOL *)outIsPacked error:(NSError **)error {
    if (theBlobKey == nil) {
        SETNSERROR([self errorDomain], -1, @"containsBlobForBlobKey: theBlobKey is nil!");
        return nil;
    }
    
    if ([theBlobKey storageType] == StorageTypeGlacier) {
        // (Legacy) Glacier archives are never deleted, so we return YES:
        return [NSNumber numberWithBool:YES];
    }
    NSError *myError = nil;
    NSNumber *ret = [blobsPackSet containsBlobInCacheForSHA1:[theBlobKey sha1] error:&myError];
    if (ret == nil) {
        HSLogError(@"error checking if pack set contains blob: %@", myError);
        SETERRORFROMMYERROR;
        return nil;
    }
    if ([ret boolValue] && outIsPacked != NULL) {
        *outIsPacked = YES;
    }
    if (![ret boolValue]) {
        ret = [fark containsObjectInCacheForSHA1:[theBlobKey sha1] storageType:[theBlobKey storageType] error:error];
    }
    return ret;
}
- (NSNumber *)sizeOfBlobInCacheForBlobKey:(BlobKey *)theBlobKey error:(NSError **)error {
    if (theBlobKey == nil) {
        SETNSERROR([self errorDomain], -1, @"sizeOfBlobInCacheForBlobKey: theBlobKey is nil!");
        return nil;
    }
    
    if ([theBlobKey storageType] == StorageTypeGlacier) {
        // We have no idea.
        return [NSNumber numberWithUnsignedLongLong:0];
    }
    
    NSError *myError = nil;
    NSNumber *ret = [blobsPackSet sizeOfBlobInCacheForSHA1:[theBlobKey sha1] error:&myError];
    if (ret == nil) {
        if ([myError code] != ERROR_NOT_FOUND) {
            SETERRORFROMMYERROR;
            return nil;
        }
        ret = [fark sizeOfObjectInCacheForSHA1:[theBlobKey sha1] storageType:[theBlobKey storageType] error:error];
    }
    return ret;
}
- (NSNumber *)isObjectDownloadableForBlobKey:(BlobKey *)theBlobKey error:(NSError **)error {
    NSError *myError = nil;
    NSNumber *ret = [blobsPackSet isObjectDownloadableForSHA1:[theBlobKey sha1] error:&myError];
    if (ret == nil) {
        if ([myError code] != ERROR_NOT_FOUND) {
            SETERRORFROMMYERROR;
            return nil;
        }
    } else {
        // Object was found in pack set.
        return ret;
    }
    
    
    // Object was not found in pack set.
    
    ret = [treesPackSet isObjectDownloadableForSHA1:[theBlobKey sha1] error:&myError];
    if (ret == nil) {
        if ([myError code] != ERROR_NOT_FOUND) {
            SETERRORFROMMYERROR;
            return nil;
        }
    } else if ([ret boolValue]) {
        return ret;
    }
    
    ret = [fark isObjectDownloadableForSHA1:[theBlobKey sha1] storageType:[theBlobKey storageType] error:error];
    return ret;
}
- (BOOL)restoreObjectForBlobKey:(BlobKey *)theBlobKey forDays:(NSUInteger)theDays tier:(int)theGlacierRetrievalTier alreadyRestoredOrRestoring:(BOOL *)alreadyRestoredOrRestoring error:(NSError **)error {
    NSError *myError = nil;
    if (![blobsPackSet restorePackForBlobWithSHA1:[theBlobKey sha1] forDays:theDays tier:theGlacierRetrievalTier alreadyRestoredOrRestoring:alreadyRestoredOrRestoring error:&myError]) {
        if ([myError code] != ERROR_NOT_FOUND) {
            SETERRORFROMMYERROR;
            return NO;
        }
        if (![treesPackSet restorePackForBlobWithSHA1:[theBlobKey sha1] forDays:theDays tier:theGlacierRetrievalTier alreadyRestoredOrRestoring:alreadyRestoredOrRestoring error:&myError]) {
            if ([myError code] != ERROR_NOT_FOUND) {
                SETERRORFROMMYERROR;
                return NO;
            }
            if (![fark restoreObjectForSHA1:[theBlobKey sha1] forDays:theDays tier:theGlacierRetrievalTier storageType:[theBlobKey storageType] alreadyRestoredOrRestoring:alreadyRestoredOrRestoring error:&myError]) {
                SETERRORFROMMYERROR;
                return NO;
            }
        }
    }
    return YES;
}
- (NSData *)dataForBlobKey:(BlobKey *)theBlobKey error:(NSError **)error {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    if (error != NULL) {
        *error = nil;
    }
    NSData *ret = [self doDataForBlobKey:theBlobKey error:error];
    [ret retain];
    if (!ret && error != NULL) {
        [*error retain];
    }
    [pool drain];
    [ret autorelease];
    if (!ret && error != NULL) {
        [*error autorelease];
    }
    return ret;
}

- (BOOL)setHeadBlobKey:(BlobKey *)theHeadBlobKey rewrite:(BOOL)rewrite error:(NSError **)error {
    HSLogDebug(@"entered setHeadBlobKey:%@ rewrite:%@", theHeadBlobKey, (rewrite ? @"YES" : @"NO"));
    
    NSAssert(theHeadBlobKey != nil, @"theHeadBlobKey must not be nil");
    NSAssert([theHeadBlobKey stretchEncryptionKey], @"head SHA1 must use stretched key");
    NSError *myError = nil;
    BlobKey *currentHeadBlobKey = [self headBlobKey:&myError];
    if (currentHeadBlobKey == nil && ![myError isErrorWithDomain:[self errorDomain] code:ERROR_NOT_FOUND]) {
        HSLogError(@"error reading current headBlobKey: %@", myError);
        SETERRORFROMMYERROR;
        return NO;
    }
    
    BOOL ret = YES;
    if (currentHeadBlobKey == nil || ![currentHeadBlobKey isEqual:theHeadBlobKey]) {
        NSError *myError = nil;
        if (![blobsPackSet commit:&myError]) {
            HSLogError(@"error committing blobs packset: %@", myError);
            SETERRORFROMMYERROR;
            return NO;
        }
        
        if (![treesPackSet commit:&myError]) {
            HSLogError(@"error committing trees packset: %@", myError);
            SETERRORFROMMYERROR;
            return NO;
        }
        
        PackIndexEntry *pie = [treesPackSet packIndexEntryForSHA1:[theHeadBlobKey sha1] error:&myError];
        if (pie == nil) {
            HSLogError(@"failed to get pack index entry for our head blob key!: %@", myError);
            SETERRORFROMMYERROR;
            return NO;
        }
        
        HSLogDebug(@"%@ putting head BlobKey %@ in repo", self, theHeadBlobKey);
        if (![fark setHeadBlobKey:theHeadBlobKey forBucketUUID:[bucket bucketUUID] error:error]) {
            return NO;
        }
        
        if (![self writeReflogForOldHeadBlobKey:currentHeadBlobKey newHeadBlobKey:theHeadBlobKey isRewrite:rewrite packIndexEntry:pie error:&myError]) {
            HSLogError(@"error writing to reflog: %@", myError);
        }
        
        NSUInteger tries = 0;
        NSTimeInterval sleepInterval = 2.0;
        for (;;) {
            [NSThread sleepForTimeInterval:sleepInterval];
            sleepInterval *= 2.0;
            if (sleepInterval > 30.0) {
                sleepInterval = 30.0;
            }
            NSError *myError = nil;
            BlobKey *receivedHeadBlobKey = [self headBlobKey:&myError];
            if (receivedHeadBlobKey == nil) {
                if (currentHeadBlobKey == nil) {
                    if ([myError code] != ERROR_NOT_FOUND) {
                        if (error != NULL) {
                            *error = myError;
                        }
                        HSLogError(@"error re-reading headBlobKey");
                        ret = NO;
                        break;
                    }
                }
            } else {
                if ([receivedHeadBlobKey isEqualToBlobKey:theHeadBlobKey]) {
                    HSLogDebug(@"received head BlobKey %@ matches expected %@", [receivedHeadBlobKey description], [theHeadBlobKey description]);
                    break;
                }
            }
            if (++tries > MAX_CONSISTENCY_TRIES) {
                HSLogError(@"received head BlobKey %@ still doesn't match expected %@; giving up", [receivedHeadBlobKey description], [theHeadBlobKey description]);
                SETNSERROR([self errorDomain], ERROR_DELAYS_IN_S3_EVENTUAL_CONSISTENCY, @"%@ seems to be experiencing long eventual-consistency delays", [[bucket target] endpointDisplayName]);
                ret = NO;
                break;
            }
            if (![targetConnectionDelegate targetConnectionShouldRetryOnTransientError:error]) {
                ret = NO;
                break;
            }
            HSLogDetail(@"received head BlobKey %@ doesn't match expected %@; retrying", [receivedHeadBlobKey description], [theHeadBlobKey description]);
        }
        if (!ret) {
            return NO;
        }
        
        [repoDelegate headBlobKeyDidChangeForTargetUUID:[[bucket target] targetUUID] computerUUID:[bucket computerUUID] bucketUUID:[bucket bucketUUID] from:currentHeadBlobKey to:theHeadBlobKey rewrite:rewrite];
    } else {
        HSLogDebug(@"current head blob key %@ already matches %@", currentHeadBlobKey, theHeadBlobKey);
    }
    
    return YES;
}
- (BOOL)deleteHeadBlobKey:(NSError **)error {
    if (![fark deleteHeadBlobKeyForBucketUUID:[bucket bucketUUID] error:error]) {
        return NO;
    }
    [repoDelegate headBlobKeyWasDeletedForTargetUUID:[[bucket target] targetUUID] computerUUID:[bucket computerUUID] bucketUUID:[bucket bucketUUID]];
    return YES;
}
- (NSData *)encryptV1Data:(NSData *)theData error:(NSError **)error {
    return [encryptor encryptV1Data:theData error:error];
}
- (BlobKey *)blobKeyForV1Data:(NSData *)theData compressionType:(BlobKeyCompressionType)theCompressionType error:(NSError **)error {
    StorageType convertedStorageType = ([bucket storageType] == StorageTypeGlacier) ? StorageTypeS3Glacier : [bucket storageType];
    return [self blobKeyForV1Data:theData compressionType:theCompressionType storageType:convertedStorageType error:error];
}
- (BlobKey *)blobKeyForV1Data:(NSData *)theData compressionType:(BlobKeyCompressionType)theCompressionType storageType:(StorageType)theStorageType error:(NSError **)error {
    NSString *theSHA1 = [SHA1Hash hashData:theData];
    return [[[BlobKey alloc] initWithSHA1:theSHA1 storageType:theStorageType stretchEncryptionKey:YES compressionType:theCompressionType error:error] autorelease];
}
- (BlobKey *)blobKeyForV2Data:(NSData *)theFileData compressionType:(BlobKeyCompressionType)theCompressionType error:(NSError **)error {
    StorageType convertedStorageType = ([bucket storageType] == StorageTypeGlacier) ? StorageTypeS3Glacier : [bucket storageType];
    return [self blobKeyForV2Data:theFileData compressionType:theCompressionType storageType:convertedStorageType error:error];
}
- (BlobKey *)blobKeyForV2Data:(NSData *)theFileData compressionType:(BlobKeyCompressionType)theCompressionType storageType:(StorageType)theStorageType error:(NSError **)error {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    BlobKey *ret = [self doBlobKeyForV2Data:theFileData compressionType:theCompressionType storageType:theStorageType error:error];
    
    [ret retain];
    if (ret == nil && error != NULL) {
        [*error retain];
    }
    [pool drain];
    [ret autorelease];
    if (ret == nil & error != NULL) {
        [*error autorelease];
    }
    return ret;
}
- (BlobKey *)doBlobKeyForV2Data:(NSData *)theFileData compressionType:(BlobKeyCompressionType)theCompressionType storageType:(StorageType)theStorageType error:(NSError **)error {
    NSString *theSHA1 = [encryptor sha1HashForV2Data:theFileData];
    return [[[BlobKey alloc] initWithSHA1:theSHA1 storageType:theStorageType stretchEncryptionKey:YES compressionType:theCompressionType error:error] autorelease];
}
- (NSData *)encryptedObjectForBlobKey:(BlobKey *)theBlobKey v2CompressedData:(NSData *)theV2CompressedData masterIV:(NSData *)theMasterIV dataIVAndSymmetricKey:(NSData *)theDataIVAndSymmetricKey error:(NSError **)error {
    
    // Lock for safety.
    [compressEncryptLock lock];
    
    // Make encrypted object from compressed data.
    NSData *ret = [encryptor v2EncryptedObjectFromData:theV2CompressedData masterIV:theMasterIV dataIVAndSymmetricKey:theDataIVAndSymmetricKey error:error];
    
    // Unlock.
    [compressEncryptLock unlock];
    
    return ret;
}


- (NSData *)decryptData:(NSData *)theData error:(NSError **)error {
    //    return [stretchedCryptoKey decrypt:theData error:error];
    return [encryptor decryptedDataForObject:theData error:error];
}
- (BOOL)deleteBlobForBlobKey:(BlobKey *)theBlobKey error:(NSError **)error {
    if (![blobsPackSet deleteBlobForSHA1:[theBlobKey sha1] error:error]) {
        return NO;
    }
    
    if (![fark deleteObjectForSHA1:[theBlobKey sha1] storageType:[theBlobKey storageType] error:error]) {
        return NO;
    }
    return YES;
}


#pragma mark PackSetActivityListener
- (void)packSetActivity:(NSString *)theActivity {
    [repoActivityListener repoActivity:theActivity];
}
- (void)packSetActivityDidFinish {
    [repoActivityListener repoActivityDidFinish];
}


#pragma mark NSObject
- (NSString *)description {
    return [NSString stringWithFormat:@"<Repo:bucket=%@>", bucket];
}


#pragma mark internal
- (Commit *)doCommitForBlobKey:(BlobKey *)commitBlobKey dataSize:(unsigned long long *)dataSize error:(NSError **)error {
    NSError *myError = nil;
    NSData *data = [treesPackSet dataForSHA1:[commitBlobKey sha1] withRetry:YES error:&myError];
    if (data == nil) {
        SETERRORFROMMYERROR;
        if ([myError isErrorWithDomain:[treesPackSet errorDomain] code:ERROR_NOT_FOUND]) {
            HSLogDebug(@"commit %@ not found in pack set", commitBlobKey);
            SETNSERROR([self errorDomain], ERROR_NOT_FOUND, @"Backup record %@ not found", [commitBlobKey sha1]);
        }
        return nil;
    }
    data = [self decryptData:data forBlobKey:commitBlobKey error:error];
    if (data == nil) {
        return nil;
    }
    
    if (dataSize != NULL) {
        *dataSize = (unsigned long long)[data length];
    }
    
    DataInputStream *dis = [[DataInputStream alloc] initWithData:data description:[NSString stringWithFormat:@"Commit %@", commitBlobKey]];
    BufferedInputStream *bis = [[BufferedInputStream alloc] initWithUnderlyingStream:dis];
    Commit *commit = [[[Commit alloc] initWithBufferedInputStream:bis error:error] autorelease];
    [bis release];
    [dis release];
    return commit;
}
- (Tree *)doTreeForBlobKey:(BlobKey *)blobKey dataSize:(unsigned long long *)dataSize error:(NSError **)error {
    NSError *myError = nil;
    NSData *data = [treesPackSet dataForSHA1:[blobKey sha1] withRetry:YES error:&myError];
    if (data == nil) {
        if ([myError isErrorWithDomain:[treesPackSet errorDomain] code:ERROR_NOT_FOUND]) {
            HSLogDebug(@"tree %@ not found in pack set", blobKey);
            SETNSERROR([self errorDomain], ERROR_NOT_FOUND, @"tree %@ not found", blobKey);
        } else {
            HSLogError(@"error reading tree %@: %@", blobKey, [myError localizedDescription]);
            if (error != NULL) {
                *error = myError;
            }
        }
        return nil;
    }
    data = [self decryptData:data forBlobKey:blobKey error:error];
    if (data == nil) {
        return nil;
    }
    if ([blobKey compressionType] != BlobKeyCompressionNone) {
        data = [data uncompress:[blobKey compressionType] error:error];
        if (data == nil) {
            return nil;
        }
    }
    
    if (dataSize != NULL) {
        *dataSize = (unsigned long long)[data length];
    }
    
    DataInputStream *dis = [[[DataInputStream alloc] initWithData:data description:[NSString stringWithFormat:@"Tree %@", [blobKey description]]] autorelease];
    BufferedInputStream *bis = [[[BufferedInputStream alloc] initWithUnderlyingStream:dis] autorelease];
    Tree *tree = [[[Tree alloc] initWithBufferedInputStream:bis error:error] autorelease];
    return tree;
}
- (NSData *)doDataForBlobKey:(BlobKey *)theBlobKey error:(NSError **)error {
    if ([theBlobKey storageType] == StorageTypeGlacier) {
        SETNSERROR([self errorDomain], -1, @"invalid method doDataBlobForBlobKey: for Glacier BlobKey");
        return nil;
    }
    
    NSError *myError = nil;
    
    // Try packset.
    NSData *data = [blobsPackSet dataForSHA1:[theBlobKey sha1] withRetry:NO error:&myError];
    if (data == nil) {
        if (![myError isErrorWithDomain:[blobsPackSet errorDomain] code:ERROR_NOT_FOUND]) {
            // Unexpected error.
            SETERRORFROMMYERROR;
            return nil;
        }
        
        // Try fark.
        data = [fark dataForSHA1:[theBlobKey sha1] storageType:[theBlobKey storageType] error:&myError];
    }
    
    if (data == nil) {
        if ([myError isErrorWithDomain:[fark errorDomain] code:ERROR_NOT_DOWNLOADABLE]) {
            // Glacier object that's not currently downloadable.
            SETNSERROR([self errorDomain], ERROR_NOT_DOWNLOADABLE, @"%@", [myError localizedDescription]);
            return nil;
        }
        if (![myError isErrorWithDomain:[fark errorDomain] code:ERROR_NOT_FOUND]) {
            // Unexpected error.
            SETERRORFROMMYERROR;
            return nil;
        }
        
        // Clear cache and try packset again unless it's a "fake" BlobKey.
        if (![[theBlobKey sha1] isEqualToString:@"0000000000000000000000000000000000000000"]) {
            HSLogInfo(@"refreshing cache of packed objects before searching again for %@", [theBlobKey sha1]);
            if (![blobsPackSet clearCache:error]) {
                return nil;
            }
            data = [blobsPackSet dataForSHA1:[theBlobKey sha1] withRetry:YES error:&myError];
        }
    }

    if (data == nil) {
        if ([myError code] != ERROR_NOT_FOUND) {
            // Unexpected error.
            SETERRORFROMMYERROR;
            return nil;
        }
        
        if (![[bucket target] canAccessFilesByPath] && ![[theBlobKey sha1] isEqualToString:@"0000000000000000000000000000000000000000"]) {
            HSLogInfo(@"refreshing cache of non-packed objects before searching again for %@", [theBlobKey sha1]);
            // Google Drive and Amazon Drive can't just read a file by path, so we have to refresh the cache of the directory and get the item ID of the file if it actually exists.
            data = [fark dataForSHA1:[theBlobKey sha1] storageType:[theBlobKey storageType] refreshCache:YES error:&myError];
        }
    }
    
    if (data == nil) {
        if ([myError code] != ERROR_NOT_FOUND) {
            // Unexpected error.
            SETERRORFROMMYERROR;
            return nil;
        }
        
        HSLogDebug(@"object not found for %@", theBlobKey);
        SETNSERROR([self errorDomain], ERROR_NOT_FOUND, @"object not found for %@", [theBlobKey sha1]);
        return nil;
    }
    
    NSAssert(data != nil, @"data can't be nil at this point");
    
    NSData *decrypted = [self decryptData:data forBlobKey:theBlobKey error:&myError];
    if (decrypted == nil) {
        HSLogDebug(@"decrypt problem: %@", myError);
        // Between Arq 5.0.0.0 and 5.0.0.64, we didn't save the encrypted compressed buffer; we saved the compressed buffer!
        // So, if the decryption fails, it probably wasn't encrypted.
        decrypted = data;
    }
    
    return decrypted;
}
- (NSData *)decryptData:(NSData *)theData forBlobKey:(BlobKey *)theBlobKey error:(NSError **)error {
    return [encryptor decryptedDataForObject:theData blobKey:theBlobKey error:error];
}

- (BOOL)writeReflogForOldHeadBlobKey:(BlobKey *)oldHeadBlobKey newHeadBlobKey:(BlobKey *)newHeadBlobKey isRewrite:(BOOL)rewrite packIndexEntry:(PackIndexEntry *)thePIE error:(NSError **)error {
    DictNode *plist = [[[DictNode alloc] init] autorelease];
    [plist putString:[oldHeadBlobKey sha1] forKey:@"oldHeadSHA1"];
    [plist putBoolean:[oldHeadBlobKey stretchEncryptionKey] forKey:@"oldHeadStretchKey"];
    [plist putString:[newHeadBlobKey sha1] forKey:@"newHeadSHA1"];
    [plist putBoolean:[newHeadBlobKey stretchEncryptionKey] forKey:@"newHeadStretchKey"];
    [plist putBoolean:rewrite forKey:@"isRewrite"];
    [plist putString:[[thePIE packId] packSHA1] forKey:@"packSHA1"];
    NSData *data = [plist XMLData];
    return [fark putReflogItem:data forBucketUUID:[bucket bucketUUID] error:error];
}

@end
