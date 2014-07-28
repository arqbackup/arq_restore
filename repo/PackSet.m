//
//  PackSet.m
//  Arq
//
//  Created by Stefan Reitshamer on 12/30/13.
//  Copyright (c) 2013 Stefan Reitshamer. All rights reserved.
//

#import "PackSet.h"
#import "Target.h"
#import "S3Service.h"
#import "PackIndexEntry.h"
#import "RegexKitLite.h"
#import "Fark.h"
#import "PackIndex.h"
#import "DataInputStream.h"
#import "BufferedInputStream.h"
#import "StringIO.h"
#import "IntegerIO.h"


#define MAX_RETRIES (10)

static unsigned long long DEFAULT_MAX_PACK_FILE_SIZE_MB = 5;
static unsigned long long DEFAULT_MAX_PACK_ITEM_SIZE_BYTES = 65536;
static double DEFAULT_MAX_REUSABLE_PACK_FILE_SIZE_FRACTION = 0.6;


@implementation PackSet

+ (unsigned long long)maxPackFileSizeMB {
    return DEFAULT_MAX_PACK_FILE_SIZE_MB;
}
+ (unsigned long long)maxPackItemSizeBytes {
    return DEFAULT_MAX_PACK_ITEM_SIZE_BYTES;
}

- (id)initWithFark:(id <Fark>)theFark
       storageType:(StorageType)theStorageType
       packSetName:(NSString *)thePackSetName
  savePacksToCache:(BOOL)theSavePacksToCache
         targetUID:(uid_t)theTargetUID
         targetGID:(gid_t)theTargetGID
loadExistingMutablePackFiles:(BOOL)theLoadExistingMutablePackFiles {
    if (self = [super init]) {
        fark = [theFark retain];
        storageType = theStorageType;
        packSetName = [thePackSetName retain];
        savePacksToCache = theSavePacksToCache;
        targetUID = theTargetUID;
        targetGID = theTargetGID;
        loadExistingMutablePackFiles = theLoadExistingMutablePackFiles;
    }
    return self;
}
- (void)dealloc {
    [fark release];
    [packSetName release];
    [packIndexEntriesByObjectSHA1 release];
    [super dealloc];
}

- (NSString *)errorDomain {
    return @"PackSetErrorDomain";
}

- (NSString *)packSetName {
    return packSetName;
}
- (NSNumber *)containsBlobForSHA1:(NSString *)sha1 dataSize:(unsigned long long *)dataSize error:(NSError **)error {
    if (![self loadPackIndexEntries:error]) {
        return nil;
    }
    PackIndexEntry *pie = [packIndexEntriesByObjectSHA1 objectForKey:sha1];
    BOOL contains;
    if ([packIndexEntriesByObjectSHA1 objectForKey:sha1] != nil) {
        contains = YES;
        if (dataSize != NULL) {
            *dataSize = [pie dataLength];
        }
    }
    return [NSNumber numberWithBool:contains];
}
- (PackId *)packIdForSHA1:(NSString *)theSHA1 error:(NSError **)error {
    if (![self loadPackIndexEntries:error]) {
        return nil;
    }
    PackIndexEntry *pie = [packIndexEntriesByObjectSHA1 objectForKey:theSHA1];
    if (pie == nil) {
        SETNSERROR([self errorDomain], ERROR_NOT_FOUND, @"object %@ not found in pack set %@", theSHA1, packSetName);
        return nil;
    }
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
            [packIndexEntriesByObjectSHA1 release];
            packIndexEntriesByObjectSHA1 = nil;
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
- (BOOL)restorePackForBlobWithSHA1:(NSString *)theSHA1 forDays:(NSUInteger)theDays alreadyRestoredOrRestoring:(BOOL *)alreadyRestoredOrRestoring error:(NSError **)error {
    if (![self loadPackIndexEntries:error]) {
        return NO;
    }
    PackIndexEntry *pie = [packIndexEntriesByObjectSHA1 objectForKey:theSHA1];
    if (pie == nil) {
        SETNSERROR([self errorDomain], ERROR_NOT_FOUND, @"%@ not found in packset", theSHA1);
        return NO;
    }
    NSError *myError = nil;
    if (![fark restorePackWithId:[pie packId] forDays:theDays storageType:storageType alreadyRestoredOrRestoring:alreadyRestoredOrRestoring error:&myError]) {
        SETERRORFROMMYERROR;
        if ([myError isErrorWithDomain:[fark errorDomain] code:ERROR_NOT_FOUND]) {
            SETNSERROR([self errorDomain], ERROR_NOT_FOUND, @"blob %@ not found because pack %@ not found", theSHA1, [pie packId]);
        }
        return NO;
    }
    return YES;
}
- (NSNumber *)isObjectDownloadableForSHA1:(NSString *)theSHA1 error:(NSError **)error {
    if (![self loadPackIndexEntries:error]) {
        return NO;
    }
    PackIndexEntry *pie = [packIndexEntriesByObjectSHA1 objectForKey:theSHA1];
    if (pie == nil) {
        SETNSERROR([self errorDomain], ERROR_NOT_FOUND, @"%@ not found in packset", theSHA1);
        return NO;
    }
    return [fark isPackDownloadableWithId:[pie packId] storageType:storageType error:error];
}

#pragma mark internal
- (NSData *)doDataForSHA1:(NSString *)sha1 error:(NSError **)error {
    if (storageType == StorageTypeGlacier) {
        SETNSERROR([self errorDomain], -1, @"cannot get pack data directly from Glacier");
        return nil;
    }

    if (![self loadPackIndexEntries:error]) {
        return nil;
    }
    
    NSData *ret = nil;
    PackIndexEntry *pie = [packIndexEntriesByObjectSHA1 objectForKey:sha1];
    if (pie != nil) {
        ret = [fark dataForPackIndexEntry:pie storageType:storageType error:error];
    } else {
        SETNSERROR([self errorDomain], ERROR_NOT_FOUND, @"%@ not found in pack set", sha1);
    }
    return ret;
}
- (BOOL)loadPackIndexEntries:(NSError **)error {
    if (packIndexEntriesByObjectSHA1 == nil) {
        NSMutableDictionary *theEntries = [[[NSMutableDictionary alloc] init] autorelease];
        NSSet *packIds = [fark packIdsForPackSet:packSetName storageType:storageType error:error];
        if (packIds == nil) {
            return NO;
        }
        PackId *reusedPackId = nil;
        for (PackId *packId in packIds) {
            NSError *myError = nil;
            PackIndex *packIndex = [self packIndexForPackId:packId error:&myError];
            if (packIndex == nil) {
                HSLogWarn(@"failed to get pack index for %@: %@", packId, myError);
            } else {
                NSError *piesError = nil;
                NSArray *pies = [packIndex packIndexEntries:&piesError];
                if (pies == nil) {
                    HSLogWarn(@"failed to read pack index entries for %@: %@", packId, piesError);
                } else {
                    uint64_t packLength = 0;
                    for (PackIndexEntry *pie in pies) {
                        [theEntries setObject:pie forKey:[pie objectSHA1]];
                        if (([pie offset] + [pie dataLength]) > packLength) {
                            packLength = [pie offset] + [pie dataLength];
                        }
                        //                HSLogDebug(@"loaded sha1 %@ from pack %@", [pie objectSHA1], [pie packId]);
                    }
                    if (reusedPackId == nil && packLength < [self maxReusablePackFileSizeBytes] && storageType == StorageTypeS3) {
                        reusedPackId = packId;
                    }
                }
            }
        }
        
        packIndexEntriesByObjectSHA1 = [theEntries retain];
    }
    return YES;
}
- (PackIndex *)packIndexForPackId:(PackId *)thePackId error:(NSError **)error {
    NSData *indexData = [fark indexDataForPackId:thePackId error:error];
    if (indexData == nil) {
        return nil;
    }
    return [[[PackIndex alloc] initWithPackId:thePackId indexData:indexData] autorelease];
}
- (unsigned long long)maxReusablePackFileSizeBytes {
    return (unsigned long long)((double)([PackSet maxPackFileSizeMB] * 1000000) * DEFAULT_MAX_REUSABLE_PACK_FILE_SIZE_FRACTION);
}
@end
