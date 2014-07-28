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


#import "Repo.h"
#import "FarkImpl.h"
#import "CryptoKey.h"
#import "Bucket.h"
#import "BlobKey.h"
#import "DataInputStream.h"
#import "BufferedInputStream.h"
#import "Target.h"
#import "Commit.h"
#import "Tree.h"
#import "PackSet.h"
#import "NSData-GZip.h"
#import "DictNode.h"
#import "SHA1Hash.h"
#import "Node.h"
#import "ArqSalt.h"


#define MAX_CONSISTENCY_TRIES (20)


@implementation Repo
- (id)initWithBucket:(Bucket *)theBucket
  encryptionPassword:(NSString *)theEncryptionPassword
           targetUID:(uid_t)theTargetUID
           targetGID:(gid_t)theTargetGID
loadExistingMutablePackFiles:(BOOL)theLoadExistingMutablePackFiles
targetConnectionDelegate:(id<TargetConnectionDelegate>)theTCD
        repoDelegate:(id<RepoDelegate>)theRepoDelegate
               error:(NSError **)error {
    if (self = [super init]) {
        bucket = [theBucket retain];
        targetUID = theTargetUID;
        targetGID = theTargetGID;
        targetConnectionDelegate = theTCD;
        repoDelegate = theRepoDelegate;
        cryptoKey = [[CryptoKey alloc] initLegacyWithPassword:theEncryptionPassword error:error];
        if (cryptoKey == nil) {
            [self release];
            return nil;
        }
        ArqSalt *arqSalt = [[[ArqSalt alloc] initWithTarget:[theBucket target] targetUID:theTargetUID targetGID:theTargetGID computerUUID:[theBucket computerUUID]] autorelease];
        NSData *theEncryptionSalt = [arqSalt saltWithTargetConnectionDelegate:theTCD error:error];
        if (theEncryptionSalt == nil) {
            [self release];
            return nil;
        }
        stretchedCryptoKey = [[CryptoKey alloc] initWithPassword:theEncryptionPassword salt:theEncryptionSalt error:error];
        if (stretchedCryptoKey == nil) {
            [self release];
            return nil;
        }
        fark = [[FarkImpl alloc] initWithTarget:[theBucket target]
                                   computerUUID:[theBucket computerUUID]
                       targetConnectionDelegate:theTCD
                                      targetUID:theTargetUID
                                      targetGID:theTargetGID];
        treesPackSet = [[PackSet alloc] initWithFark:fark
                                         storageType:StorageTypeS3
                                         packSetName:[[bucket bucketUUID] stringByAppendingString:@"-trees"]
                                    savePacksToCache:YES
                                           targetUID:theTargetUID
                                           targetGID:theTargetGID
                        loadExistingMutablePackFiles:theLoadExistingMutablePackFiles];
        if (treesPackSet == nil) {
            [self release];
            return nil;
        }
        
        // For StorageTypeGlacier Buckets, use StorageTypeS3Glacier going forward.
        StorageType convertedStorageType = ([bucket storageType] == StorageTypeGlacier) ? StorageTypeS3Glacier : [bucket storageType];
        blobsPackSet = [[PackSet alloc] initWithFark:fark
                                         storageType:convertedStorageType
                                         packSetName:[[bucket bucketUUID] stringByAppendingString:@"-blobs"]
                                    savePacksToCache:NO
                                           targetUID:theTargetUID
                                           targetGID:theTargetGID
                        loadExistingMutablePackFiles:theLoadExistingMutablePackFiles];
        if (blobsPackSet == nil) {
            [self release];
            return nil;
        }
    }
    return self;
}
- (void)dealloc {
    [bucket release];
    [cryptoKey release];
    [stretchedCryptoKey release];
    [fark release];
    [treesPackSet release];
    [blobsPackSet release];
    [super dealloc];
}

- (NSString *)errorDomain {
    return @"RepoErrorDomain";
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
- (NSNumber *)containsBlobForBlobKey:(BlobKey *)theBlobKey error:(NSError **)error {
    return [self containsBlobForBlobKey:theBlobKey dataSize:NULL error:error];
}
- (NSNumber *)containsBlobForBlobKey:(BlobKey *)theBlobKey dataSize:(unsigned long long *)dataSize error:(NSError **)error {
    return [self containsBlobForBlobKey:theBlobKey dataSize:dataSize forceTargetCheck:NO error:error];
}
- (NSNumber *)containsBlobForBlobKey:(BlobKey *)theBlobKey dataSize:(unsigned long long *)dataSize forceTargetCheck:(BOOL)forceTargetCheck error:(NSError **)error {
    if (theBlobKey == nil) {
        SETNSERROR([self errorDomain], -1, @"containsBlobForBlobKey: theBlobKey is nil!");
        return nil;
    }
    
    NSError *myError = nil;
    NSNumber *ret = [blobsPackSet containsBlobForSHA1:[theBlobKey sha1] dataSize:dataSize error:&myError];
    if (ret == nil) {
        HSLogError(@"error checking if pack set contains blob: %@", myError);
    } else {
        if ([ret boolValue]) {
            return ret;
        }
    }
    
    if ([theBlobKey storageType] == StorageTypeGlacier) {
        // (Legacy) Glacier archives are never deleted, so we return YES:
        return [NSNumber numberWithBool:YES];
    }
    
    return [fark containsObjectForSHA1:[theBlobKey sha1] storageType:[theBlobKey storageType] dataSize:dataSize forceTargetCheck:forceTargetCheck error:error];
}
- (NSNumber *)isObjectDownloadableForBlobKey:(BlobKey *)theBlobKey error:(NSError **)error {
    NSNumber *contains = [treesPackSet containsBlobForSHA1:[theBlobKey sha1] dataSize:NULL error:error];
    if (contains == nil) {
        return nil;
    }
    if ([contains boolValue]) {
        return [treesPackSet isObjectDownloadableForSHA1:[theBlobKey sha1] error:error];
    }
    
    contains = [blobsPackSet containsBlobForSHA1:[theBlobKey sha1] dataSize:NULL error:error];
    if (contains == nil) {
        return nil;
    }
    if ([contains boolValue]) {
        return [blobsPackSet isObjectDownloadableForSHA1:[theBlobKey sha1] error:error];
    }
    
    return [fark isObjectDownloadableForSHA1:[theBlobKey sha1] storageType:[theBlobKey storageType] error:error];
}
- (BOOL)restoreObjectForBlobKey:(BlobKey *)theBlobKey forDays:(NSUInteger)theDays alreadyRestoredOrRestoring:(BOOL *)alreadyRestoredOrRestoring error:(NSError **)error {
    // If it's in a Pack, don't try to restore it because we
    NSNumber *contains = [treesPackSet containsBlobForSHA1:[theBlobKey sha1] dataSize:NULL error:error];
    if (contains == nil) {
        return NO;
    }
    if ([contains boolValue]) {
        return [treesPackSet restorePackForBlobWithSHA1:[theBlobKey sha1] forDays:theDays alreadyRestoredOrRestoring:alreadyRestoredOrRestoring error:error];
    }

    contains = [blobsPackSet containsBlobForSHA1:[theBlobKey sha1] dataSize:NULL error:error];
    if (contains == nil) {
        return NO;
    }
    if ([contains boolValue]) {
        return [blobsPackSet restorePackForBlobWithSHA1:[theBlobKey sha1] forDays:theDays alreadyRestoredOrRestoring:alreadyRestoredOrRestoring error:error];
    }

    NSError *myError = nil;
    if (![fark restoreObjectForSHA1:[theBlobKey sha1] forDays:theDays storageType:[theBlobKey storageType] alreadyRestoredOrRestoring:alreadyRestoredOrRestoring error:&myError]) {
        SETERRORFROMMYERROR;
        if ([myError isErrorWithDomain:[fark errorDomain] code:ERROR_NOT_FOUND]) {
            SETNSERROR([self errorDomain], ERROR_NOT_FOUND, @"object %@ can't be restored because it's not found", theBlobKey);
        }
        return NO;
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

- (NSData *)decryptData:(NSData *)theData error:(NSError **)error {
    return [stretchedCryptoKey decrypt:theData error:error];
}
- (NSData *)encryptData:(NSData *)theData error:(NSError **)error {
    return [stretchedCryptoKey encrypt:theData error:error];
}

- (BOOL)addSHA1sForCommitBlobKey:(BlobKey *)commitBlobKey toSet:(NSMutableSet *)theSet error:(NSError **)error {
    if ([theSet containsObject:[commitBlobKey sha1]]) {
        return YES;
    }
    Commit *commit = [self commitForBlobKey:commitBlobKey error:error];
    if (commit == nil) {
        return NO;
    }
    if (![self addSHA1sForTreeBlobKey:[commit treeBlobKey] toSet:theSet error:error]) {
        return NO;
    }
    [theSet addObject:[commitBlobKey sha1]];
    return YES;
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
            SETNSERROR([self errorDomain], ERROR_NOT_FOUND, @"commit %@ not found", commitBlobKey);
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
    if ([blobKey compressed]) {
        data = [data gzipInflate:error];
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
    NSData *data = [blobsPackSet dataForSHA1:[theBlobKey sha1] withRetry:NO error:&myError];
    if (data == nil) {
        SETERRORFROMMYERROR;
        if (![myError isErrorWithDomain:[blobsPackSet errorDomain] code:ERROR_NOT_FOUND]) {
            // Return nil if not a not-found error.
            SETERRORFROMMYERROR;
            return nil;
        }
        data = [fark dataForSHA1:[theBlobKey sha1] storageType:[theBlobKey storageType] error:&myError];
        if (data == nil) {
            SETERRORFROMMYERROR;
            if ([myError isErrorWithDomain:[fark errorDomain] code:ERROR_NOT_DOWNLOADABLE]) {
                SETNSERROR([self errorDomain], ERROR_NOT_DOWNLOADABLE, @"%@", [myError localizedDescription]);
                return nil;
            }
            if (![myError isErrorWithDomain:[fark errorDomain] code:ERROR_NOT_FOUND]) {
                // Return nil if not a not-found error.
                return nil;
            }
            data = [blobsPackSet dataForSHA1:[theBlobKey sha1] withRetry:YES error:&myError];
            if (data == nil) {
                SETERRORFROMMYERROR;
                if ([myError isErrorWithDomain:[blobsPackSet errorDomain] code:ERROR_NOT_FOUND]) {
                    SETNSERROR([self errorDomain], ERROR_NOT_FOUND, @"object not found for %@", theBlobKey);
                }
                return nil;
            }
        }
    }
    
    NSAssert(data != nil, @"data can't be nil at this point");
    
    NSData *decrypted = [self decryptData:data forBlobKey:theBlobKey error:error];
    if (decrypted == nil) {
        return nil;
    }
    return decrypted;
}
- (NSData *)decryptData:(NSData *)theData forBlobKey:(BlobKey *)theBlobKey error:(NSError **)error {
    CryptoKey *selectedCryptoKey = [theBlobKey stretchEncryptionKey] ? stretchedCryptoKey : cryptoKey;
    return [selectedCryptoKey decrypt:theData error:error];
}
- (NSData *)encryptData:(NSData *)theData forBlobKey:(BlobKey *)theBlobKey error:(NSError **)error {
    CryptoKey *selectedCryptoKey = [theBlobKey stretchEncryptionKey] ? stretchedCryptoKey : cryptoKey;
    return [selectedCryptoKey encrypt:theData error:error];
}

- (BOOL)writeReflogForOldHeadBlobKey:(BlobKey *)oldHeadBlobKey newHeadBlobKey:(BlobKey *)newHeadBlobKey isRewrite:(BOOL)rewrite error:(NSError **)error {
    DictNode *plist = [[[DictNode alloc] init] autorelease];
    [plist putString:[oldHeadBlobKey sha1] forKey:@"oldHeadSHA1"];
    [plist putBoolean:[oldHeadBlobKey stretchEncryptionKey] forKey:@"oldHeadStretchKey"];
    [plist putString:[newHeadBlobKey sha1] forKey:@"newHeadSHA1"];
    [plist putBoolean:[newHeadBlobKey stretchEncryptionKey] forKey:@"newHeadStretchKey"];
    [plist putBoolean:rewrite forKey:@"isRewrite"];
    NSData *data = [plist XMLData];
    return [fark putReflogItem:data forBucketUUID:[bucket bucketUUID] error:error];
}
- (BOOL)addSHA1sForTreeBlobKey:(BlobKey *)treeBlobKey toSet:(NSMutableSet *)theSet error:(NSError **)error {
    if (error != NULL) {
        *error = nil;
    }
    NSAssert(treeBlobKey != nil, @"treeBlobKey can't be nil");
    if ([theSet containsObject:[treeBlobKey sha1]]) {
        return YES;
    }
    BOOL ret = YES;
    Tree *tree = [self treeForBlobKey:treeBlobKey error:error];
    if (tree == nil) {
        ret = NO;
    } else {
        if ([tree xattrsBlobKey] != nil) {
            [theSet addObject:[[tree xattrsBlobKey] sha1]];
        }
        if ([tree aclBlobKey] != nil) {
            [theSet addObject:[[tree aclBlobKey] sha1]];
        }
        NSAutoreleasePool *pool = nil;
        for (NSString *childNodeName in [tree childNodeNames]) {
            [pool drain];
            pool = [[NSAutoreleasePool alloc] init];
            Node *node = [tree childNodeWithName:childNodeName];
            NSArray *dataBlobKeys = [node dataBlobKeys];
            if ([node isTree]) {
                if ([dataBlobKeys count] != 1) {
                    SETNSERROR(@"CommitTrimmerErrorDomain", -1, @"unexpected tree %@ node %@ has %lu dataBloKeys (expected 1)", treeBlobKey, childNodeName, (unsigned long)[dataBlobKeys count]);
                    ret = NO;
                    break;
                }
                if (![self addSHA1sForTreeBlobKey:[dataBlobKeys objectAtIndex:0] toSet:theSet error:error]) {
                    ret = NO;
                    break;
                }
            }
            for (BlobKey *dataBlobKey in dataBlobKeys) {
                [theSet addObject:[dataBlobKey sha1]];
            }
            if ([node xattrsBlobKey] != nil) {
                [theSet addObject:[[node xattrsBlobKey] sha1]];
            }
            if ([node aclBlobKey] != nil) {
                [theSet addObject:[[node aclBlobKey] sha1]];
            }
        }
        if (error != NULL) {
            [*error retain];
        }
        [pool drain];
        if (error != NULL) {
            [*error autorelease];
        }
    }
    if (ret) {
        [theSet addObject:[treeBlobKey sha1]];
    }
    return ret;
}

@end
