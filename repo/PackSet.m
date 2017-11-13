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



#import "PackSet.h"
#import "Target.h"
#import "S3Service.h"
#import "PackIndexEntry.h"
#import "RegexKitLite.h"
#import "PackBuilder.h"
#import "Fark.h"
#import "PackIndex.h"
#import "DataInputStream.h"
#import "BufferedInputStream.h"
#import "StringIO.h"
#import "IntegerIO.h"
#import "PackIndexGenerator.h"
#import "PackSetDB.h"
#import "PIELoader.h"


#define MAX_RETRIES (10)

static unsigned long long DEFAULT_MAX_PACK_FILE_SIZE_MB = 5;
static unsigned long long DEFAULT_MAX_PACK_ITEM_SIZE_BYTES = 65536;
//static double DEFAULT_MAX_REUSABLE_PACK_FILE_SIZE_FRACTION = 0.6;


@implementation PackSet

+ (unsigned long long)maxPackFileSizeMB {
    return DEFAULT_MAX_PACK_FILE_SIZE_MB;
}
+ (unsigned long long)maxPackItemSizeBytes {
    return DEFAULT_MAX_PACK_ITEM_SIZE_BYTES;
}

- (id)initWithFark:(Fark *)theFark
       storageType:(StorageType)theStorageType
       packSetName:(NSString *)thePackSetName
cachePackFilesToDisk:(BOOL)theCachePackFilesToDisk
  activityListener:(id <PackSetActivityListener>)theActivityListener
             error:(NSError **)error {
    if (self = [super init]) {
        fark = [theFark retain];
        storageType = theStorageType;
        packSetName = [thePackSetName retain];
        cachePackFilesToDisk = theCachePackFilesToDisk;
        activityListener = theActivityListener;
        
        packSetDB = [[PackSetDB alloc] initWithTargetUUID:[theFark targetUUID]
                                             computerUUID:[theFark computerUUID]
                                              packSetName:thePackSetName
                                                    error:error];
        if (packSetDB == nil) {
            [self release];
            return nil;
        }
        packBuilderBuffer = [[NSMutableData alloc] init];
    }
    return self;
}
- (void)dealloc {
    [fark release];
    [packSetName release];
    [packBuilder release];
    [packSetDB release];
    [packBuilderBuffer release];
    [super dealloc];
}

- (NSString *)errorDomain {
    return @"PackSetErrorDomain";
}

- (NSString *)packSetName {
    return packSetName;
}
- (StorageType)storageType {
    return storageType;
}
- (NSNumber *)sizeOfBlobInCacheForSHA1:(NSString *)sha1 error:(NSError **)error {
    if ([packBuilder containsObjectForSHA1:sha1]) {
        NSData *data = [packBuilder dataForSHA1:sha1 error:error];
        if (data == nil) {
            return nil;
        }
        return [NSNumber numberWithUnsignedLongLong:[data length]];
    }
    PackIndexEntry *pie = [self packIndexEntryForSHA1:sha1 error:error];
    if (pie == nil) {
        return nil;
    }
    return [NSNumber numberWithUnsignedLongLong:[pie dataLength]];
}
- (NSNumber *)containsBlobInCacheForSHA1:(NSString *)sha1 error:(NSError **)error {
    BOOL contains = NO;

    NSError *myError = nil;
    PackIndexEntry *pie = [self packIndexEntryForSHA1:sha1 error:&myError];
    if (pie == nil && ![myError isErrorWithDomain:[self errorDomain] code:ERROR_NOT_FOUND]) {
        SETERRORFROMMYERROR;
        return nil;
    } else if (pie != nil) {
        contains = YES;
    } else if (packBuilder != nil) {
        contains = [packBuilder containsObjectForSHA1:sha1];
    }
    return [NSNumber numberWithBool:contains];
}
- (PackId *)packIdForSHA1:(NSString *)theSHA1 error:(NSError **)error {
    PackIndexEntry *pie = [self packIndexEntryForSHA1:theSHA1 error:error];
    if (pie == nil) {
        return nil;
    }
    NSAssert([pie packId] != nil, @"[pie packId] may not be nil");
    return [pie packId];
}
- (NSData *)dataForSHA1:(NSString *)sha1 withRetry:(BOOL)retry error:(NSError **)error {
    NSData *ret = nil;
    NSUInteger i = 0;
    NSUInteger maxRetries = retry ? MAX_RETRIES : 1;
    NSAutoreleasePool *pool = nil;
    for (i = 0; i < maxRetries; i++) {
        [pool drain];
        pool = [[NSAutoreleasePool alloc] init];
        NSError *myError = nil;
        ret = [self doDataForSHA1:sha1 error:&myError];
        if (ret != nil) {
            break;
        }
        
        if ([myError isErrorWithDomain:[fark errorDomain] code:ERROR_NOT_FOUND]) {
            // Pack was missing. Agent must have replaced it. Try again.
            PackIndexEntry *pie = [self packIndexEntryForSHA1:sha1 error:error];
            if (pie != nil) {
                if (![packSetDB deletePackId:[pie packId] error:error]) {
                    return nil;
                }
            }
        } else if ([myError isErrorWithDomain:[fark errorDomain] code:ERROR_INVALID_PACK_INDEX_ENTRY]) {
            // Up to Arq 4.5.3, PackIndexGenerator didn't include the 10 bytes for 2 nil strings and a data length when calculating offsets when recreating index files.
            // Delete the index and recreate it.
            
            HSLogError(@"invalid pack index entry (recreating index): %@", myError);
            
            PackIndexEntry *pie = [[[self packIndexEntryForSHA1:sha1 error:error] retain] autorelease];
            if (pie == nil) {
                // This should never happen.
                break;
            }
            
            HSLogInfo(@"deleting bad index for %@", [pie packId]);
            if (![fark deleteIndex:[pie packId] error:&myError]) {
                HSLogError(@"failed to delete broken index for %@: %@", [pie packId], myError);
            }
            
            if (storageType == StorageTypeS3Glacier) {
                // Restore the pack if necessary.
                HSLogInfo(@"restoring pack %@ in order to recreate index", [pie packId]);
                if (![fark restorePackWithId:[pie packId] forDays:10 tier:GLACIER_RETRIEVAL_TIER_EXPEDITED storageType:storageType alreadyRestoredOrRestoring:NULL error:error]) {
                    return nil;
                }
                for (;;) {
                    NSNumber *downloadable = [fark isPackDownloadableWithId:[pie packId] storageType:storageType error:error];
                    if (downloadable == nil) {
                        return nil;
                    }
                    if ([downloadable boolValue]) {
                        HSLogDebug(@"pack is downloadable");
                        break;
                    }
                    HSLogDetail(@"waiting for pack %@ to be downloadable", [pie packId]);
                    [NSThread sleepForTimeInterval:10.0];
                }
            }
            NSData *packData = [fark packDataForPackId:[pie packId] storageType:storageType error:error];
            if (packData == nil) {
                return nil;
            }
            PackIndexGenerator *pig = [[[PackIndexGenerator alloc] initWithPackId:[pie packId] packData:packData] autorelease];
            NSData *indexData = [pig indexData:error];
            HSLogInfo(@"storing fixed index for %@", [pie packId]);
            if (![fark putIndexData:indexData forPackId:[pie packId] error:error]) {
                return nil;
            }
        } else {
            SETERRORFROMMYERROR;
            break;
        }
    }
    [ret retain];
    if (ret == nil && error != NULL) {
        [*error retain];
    }
    [pool drain];
    [ret autorelease];
    if (ret == nil && error != NULL) {
        [*error autorelease];
    }
    
    return ret;
}
- (BOOL)putData:(NSData *)theData sha1:(NSString *)sha1 error:(NSError **)error {
    NSError *myError = nil;

    if (packBuilder == nil) {
        packBuilder = [[PackBuilder alloc] initWithFark:fark storageType:storageType packSetName:packSetName buffer:packBuilderBuffer cachePackFilesToDisk:cachePackFilesToDisk];
    }

    PackIndexEntry *existing = [self packIndexEntryForSHA1:sha1 error:&myError];
    if (existing == nil) {
        if (![myError isErrorWithDomain:[self errorDomain] code:ERROR_NOT_FOUND]) {
            SETERRORFROMMYERROR;
            return NO;
        }
    }
    if (existing == nil) {
        [packBuilder addData:theData forSHA1:sha1];
    }
    
    unsigned long long maxPackFileSize = [PackSet maxPackFileSizeMB] * 1000000;
    if ([packBuilder size] > maxPackFileSize) {
        HSLogDebug(@"pack builder is full for pack set %@", packSetName);
        if (![self commit:error]) {
            return NO;
        }
    }
    return YES;
}
- (BOOL)commit:(NSError **)error {
    if ([packBuilder size] > 0 && [packBuilder isModified]) {
        PackId *newPackId = [packBuilder commit:error];
        if (newPackId == nil) {
            return NO;
        }
        HSLogDebug(@"committed new pack %@", newPackId);
        
        [packBuilder release];
        packBuilder = nil;

        PackIndex *newPackIndex = [self packIndexForPackId:newPackId error:error];
        if (newPackIndex == nil) {
            return NO;
        }
        NSArray *newPIEs = [newPackIndex packIndexEntries:error];
        if (newPIEs == nil) {
            return NO;
        }
        if (![packSetDB insertPackId:newPackId packIndexEntries:newPIEs error:error]) {
            return NO;
        }
    }
    return YES;
}
- (BOOL)restorePackForBlobWithSHA1:(NSString *)theSHA1 forDays:(NSUInteger)theDays tier:(int)theGlacierRetrievalTier alreadyRestoredOrRestoring:(BOOL *)alreadyRestoredOrRestoring error:(NSError **)error {
    PackIndexEntry *pie = [self packIndexEntryForSHA1:theSHA1 error:error];
    if (pie == nil) {
        return NO;
    }
    NSError *myError = nil;
    if (![fark restorePackWithId:[pie packId] forDays:theDays tier:theGlacierRetrievalTier storageType:storageType alreadyRestoredOrRestoring:alreadyRestoredOrRestoring error:&myError]) {
        SETERRORFROMMYERROR;
        if ([myError isErrorWithDomain:[fark errorDomain] code:ERROR_NOT_FOUND]) {
            SETNSERROR([self errorDomain], ERROR_NOT_FOUND, @"blob %@ not found because pack %@ not found", theSHA1, [pie packId]);
        }
        return NO;
    }
    return YES;
}
- (NSNumber *)isObjectDownloadableForSHA1:(NSString *)theSHA1 error:(NSError **)error {
    PackIndexEntry *pie = [self packIndexEntryForSHA1:theSHA1 error:error];
    if (pie == nil) {
        return nil;
    }
    return [fark isPackDownloadableWithId:[pie packId] storageType:storageType error:error];
}

- (BOOL)consolidate:(NSError **)error {
    HSLogDebug(@"not consolidating packs for now");
    return YES;
}
- (BOOL)clearCache:(NSError **)error {
    if (![fark clearCachedPackIdsForPackSet:packSetName storageType:storageType error:error]) {
        return NO;
    }
    cacheIsLoaded = NO;
    return YES;
}
- (void)reloadCache {
    cacheIsLoaded = NO;
}
- (BOOL)deleteBlobForSHA1:(NSString *)theSHA1 error:(NSError **)error {
    HSLogInfo(@"deleting invalid object %@", theSHA1);
    NSError *myError = nil;
    PackIndexEntry *foundPIE = [self packIndexEntryForSHA1:theSHA1 error:&myError];
    if (foundPIE == nil) {
        if ([myError code] != ERROR_NOT_FOUND) {
            SETERRORFROMMYERROR;
            return NO;
        }
        // sha1 not found in pack set.
        return YES;
    }
        // Load the pack's data into a PackBuilder minus the blob for theSHA1, save it, and delete the old pack.
    PackIndex *packIndex = [self packIndexForPackId:[foundPIE packId] error:error];
    if (packIndex == nil) {
        return NO;
    }
    NSArray *pies = [packIndex packIndexEntries:error];
    if (pies == nil) {
        return NO;
    }
    
    if (packBuilder == nil) {
        packBuilder = [[PackBuilder alloc] initWithFark:fark storageType:storageType packSetName:packSetName buffer:packBuilderBuffer cachePackFilesToDisk:cachePackFilesToDisk];
    }
        
    for (PackIndexEntry *thePIE in pies) {
        if (![[thePIE objectSHA1] isEqualToString:theSHA1]) {
            NSData *pieData = [self dataForSHA1:[thePIE objectSHA1] withRetry:NO error:error];
            if (pieData == nil) {
                return NO;
            }
            [packBuilder addData:pieData forSHA1:[thePIE objectSHA1]];
        }
    }
    [packBuilder removeDataForSHA1:theSHA1];
    if (![self commit:error]) {
        return NO;
    }
    if (![fark deletePack:[foundPIE packId] storageType:storageType error:&myError]) {
        SETERRORFROMMYERROR;
        HSLogError(@"failed to delete pack %@ with invalid object %@: %@", [foundPIE packId], theSHA1, myError);
        return NO;
    }
    if (![fark deleteIndex:[foundPIE packId] error:&myError]) {
        SETERRORFROMMYERROR;
        HSLogError(@"failed to delete index %@ with invalid object %@: %@", [foundPIE packId], theSHA1, myError);
        return NO;
    }
    return YES;
}


- (PackIndexEntry *)packIndexEntryForSHA1:(NSString *)theSHA1 error:(NSError **)error {
    if (![self loadCache:error]) {
        return nil;
    }
    
    NSError *myError = nil;
    PackIndexEntry *ret = [packSetDB packIndexEntryForSHA1:theSHA1 error:&myError];
    if (ret == nil) {
        if (![myError isErrorWithDomain:[PackSetDB errorDomain] code:ERROR_NOT_FOUND]) {
            SETERRORFROMMYERROR;
        } else {
            SETNSERROR([self errorDomain], ERROR_NOT_FOUND, @"object %@ not found in pack set %@", theSHA1, packSetName);
        }
    }
    return ret;
}

#pragma mark internal
- (NSData *)doDataForSHA1:(NSString *)sha1 error:(NSError **)error {
    if (storageType == StorageTypeGlacier) {
        SETNSERROR([self errorDomain], -1, @"cannot get pack data directly from Glacier");
        return nil;
    }

    NSData *ret = nil;
    NSError *myError = nil;
    PackIndexEntry *pie = [self packIndexEntryForSHA1:sha1 error:&myError];
    if (pie == nil && [myError code] != ERROR_NOT_FOUND) {
        SETERRORFROMMYERROR;
        return nil;
    }
    if (pie != nil) {
//        HSLogDebug(@"packed sha1 %@ found in %@", sha1, pie);
        ret = [fark dataForPackIndexEntry:pie storageType:storageType error:error];
    } else {
        // Check PackBuilder.
        if (packBuilder != nil) {
            NSError *myError = nil;
            ret = [packBuilder dataForSHA1:sha1 error:&myError];
            if (ret == nil) {
                if ([myError isErrorWithDomain:[packBuilder errorDomain] code:ERROR_NOT_FOUND]) {
                    SETNSERROR([self errorDomain], ERROR_NOT_FOUND, @"%@ not found in packset", sha1);
                } else {
                    if (error != NULL) {
                        *error = myError;
                    }
                }
            } else {
                HSLogDebug(@"packed sha1 %@ found in pack builder", sha1);
            }
        } else {
            HSLogDebug(@"packed sha1 %@ not found", sha1);
            SETNSERROR([self errorDomain], ERROR_NOT_FOUND, @"%@ not found in packset", sha1);
        }
    }
    return ret;
}
- (BOOL)loadCache:(NSError **)error {
    if (!cacheIsLoaded) {
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        BOOL ret = [self doLoadCache:error];
        if (!ret && error != NULL) {
            [*error retain];
        }
        [pool drain];
        if (!ret && error != NULL) {
            [*error autorelease];
        }
        if (!ret) {
            return NO;
        }
        
        cacheIsLoaded = YES;
    }
    return YES;
}
- (BOOL)doLoadCache:(NSError **)error {
    [activityListener packSetActivity:@"Reading pack list..."];
    
    NSSet *actualPackIds = [fark packIdsForPackSet:packSetName storageType:storageType error:error];
    if (actualPackIds == nil) {
        return NO;
    }
    HSLogDebug(@"%@: %ld packIds found", packSetName, [actualPackIds count]);
    
    NSSet *packIdsInDB = [packSetDB packIds:error];
    if (packIdsInDB == nil) {
        return NO;
    }
    HSLogDebug(@"%@: %ld packIds already in DB", packSetName, [packIdsInDB count]);
    
    // Cache all pack index data in the database.
    NSMutableSet *packIdsNotInDB = [NSMutableSet setWithSet:actualPackIds];
    [packIdsNotInDB minusSet:packIdsInDB];
    NSArray *packIdsArray = [packIdsNotInDB allObjects];
    if ([packIdsArray count] > 0) {
        PIELoader *pieLoader = [[[PIELoader alloc] initWithDelegate:self packIds:packIdsArray fark:fark storageType:storageType] autorelease];
        if (![pieLoader waitForCompletion:error]) {
            return NO;
        }
    }
    
    // Remove packs from database that don't exist at the target.
    NSMutableSet *packIdsNotAtTarget = [NSMutableSet setWithSet:packIdsInDB];
    [packIdsNotAtTarget minusSet:actualPackIds];
    for (PackId *packId in packIdsNotAtTarget) {
        if (![packSetDB deletePackId:packId error:error]) {
            return NO;
        }
    }
    [activityListener packSetActivityDidFinish];

    return YES;
}


- (PackIndex *)packIndexForPackId:(PackId *)thePackId error:(NSError **)error {
    NSError *myError = nil;
    NSData *indexData = [fark indexDataForPackId:thePackId error:&myError];
    if (indexData == nil) {
        if ([myError code] != ERROR_NOT_FOUND) {
            SETERRORFROMMYERROR;
            return nil;
        }
        if (storageType == StorageTypeS3) {
            // Rebuild the index from the S3 pack:
            NSData *packData = [fark packDataForPackId:thePackId storageType:storageType error:error];
            if (packData == nil) {
                return nil;
            }
            PackIndexGenerator *pig = [[[PackIndexGenerator alloc] initWithPackId:thePackId packData:packData] autorelease];
            indexData = [pig indexData:error];
            if (indexData == nil) {
                // Failed to read the pack. Delete the pack.
                SETERRORFROMMYERROR;
                return nil;
            }
            if (![fark putIndexData:indexData forPackId:thePackId error:error]) {
                return nil;
            }
        } else {
            // Can't load the pack in real time, so we can't rebuild an index file.
            SETERRORFROMMYERROR;
            return nil;
        }
    }
    return [[[PackIndex alloc] initWithPackId:thePackId indexData:indexData] autorelease];
}

#pragma mark PIELoaderDelegate
- (BOOL)pieLoaderDidLoadPackIndexEntries:(NSArray *)thePIEs forPackId:(PackId *)thePackId index:(NSUInteger)theIndex total:(NSUInteger)theTotal error:(NSError **)error {
    [activityListener packSetActivity:[NSString stringWithFormat:@"Caching pack index %ld of %ld", theIndex, theTotal]];
    return [packSetDB insertPackId:thePackId packIndexEntries:thePIEs error:error];
}
@end
