#import "Arq6Snapshot.h"
#import "Arq6SnapshotVolume.h"
#import "Arq7KeySet.h"
#import "Arq7EncryptedObjectDecryptor.h"
#import "Arq7Node.h"
#import "TargetConnection.h"
#import "Item.h"
#include "lz4.h"
#include <libkern/OSByteOrder.h>


@interface Arq6Snapshot() {
    NSDate *_creationDate;
    BOOL _isComplete;
    NSString *_planUUID;
    NSDictionary *_volumesByDiskIdentifier;
}
@end


@implementation Arq6Snapshot

+ (BOOL)isArq6PlanUUID:(NSString *)thePlanUUID
      targetConnection:(TargetConnection *)theConn
              delegate:(id <TargetConnectionDelegate>)theDelegate {
    // A plan is Arq 6 if it has a snapshots/ directory but no backupfolders/ directory.
    // Migrated plans have both; those are Arq 7.
    NSError *myError = nil;
    NSString *snapshotsPath = [NSString stringWithFormat:@"%@/%@/snapshots", [theConn pathPrefix], thePlanUUID];
    NSNumber *hasSnapshots = [theConn fileExistsAtPath:snapshotsPath dataSize:NULL delegate:theDelegate error:&myError];
    if (hasSnapshots == nil || ![hasSnapshots boolValue]) {
        return NO;
    }
    NSString *foldersPath = [NSString stringWithFormat:@"%@/%@/backupfolders", [theConn pathPrefix], thePlanUUID];
    NSNumber *hasFolders = [theConn fileExistsAtPath:foldersPath dataSize:NULL delegate:theDelegate error:&myError];
    return (hasFolders == nil || ![hasFolders boolValue]);
}

+ (Arq6Snapshot *)mostRecentSnapshotForPlanUUID:(NSString *)thePlanUUID
                                targetConnection:(TargetConnection *)theConn
                                          keySet:(Arq7KeySet *)theKeySet
                                        delegate:(id <TargetConnectionDelegate>)theDelegate
                                           error:(NSError **)error {
    NSString *snapshotsPath = [NSString stringWithFormat:@"%@/%@/snapshots", [theConn pathPrefix], thePlanUUID];

    NSDictionary *dirsByName = [theConn itemsByNameAtPath:snapshotsPath
                                targetConnectionDelegate:theDelegate
                                                   error:error];
    if (dirsByName == nil) {
        return nil;
    }

    NSArray *sortedDirNames = [[dirsByName allKeys] sortedArrayUsingSelector:@selector(compare:)];
    for (NSString *dirName in [sortedDirNames reverseObjectEnumerator]) {
        if ([dirName isEqualToString:@".DS_Store"] || [dirName isEqualToString:@"@eaDir"]) {
            continue;
        }
        Item *dirItem = [dirsByName objectForKey:dirName];
        if (![dirItem isDirectory]) {
            continue;
        }

        NSString *subDir = [snapshotsPath stringByAppendingPathComponent:dirName];
        NSDictionary *filesByName = [theConn itemsByNameAtPath:subDir
                                       targetConnectionDelegate:theDelegate
                                                          error:error];
        if (filesByName == nil) {
            return nil;
        }

        NSArray *sortedFileNames = [[filesByName allKeys] sortedArrayUsingSelector:@selector(compare:)];
        for (NSString *fileName in [sortedFileNames reverseObjectEnumerator]) {
            if (![fileName hasSuffix:@".snapshot"]) {
                continue;
            }
            NSString *filePath = [subDir stringByAppendingPathComponent:fileName];
            NSError *myError = nil;
            Arq6Snapshot *snapshot = [Arq6Snapshot snapshotAtPath:filePath
                                                  targetConnection:theConn
                                                            keySet:theKeySet
                                                          delegate:theDelegate
                                                             error:&myError];
            if (snapshot == nil) {
                HSLogError(@"failed to read snapshot %@: %@", filePath, myError);
                continue;
            }
            if (snapshot.isComplete) {
                return snapshot;
            }
        }
    }

    SETNSERROR(@"Arq6SnapshotErrorDomain", ERROR_NOT_FOUND,
               @"no complete snapshot found for plan %@", thePlanUUID);
    return nil;
}

+ (Arq6Snapshot *)snapshotAtPath:(NSString *)thePath
                 targetConnection:(TargetConnection *)theConn
                           keySet:(Arq7KeySet *)theKeySet
                         delegate:(id <TargetConnectionDelegate>)theDelegate
                            error:(NSError **)error {
    NSData *rawData = [theConn contentsOfFileAtPath:thePath delegate:theDelegate error:error];
    if (rawData == nil) {
        return nil;
    }

    // Step 1: decrypt if ARQO-prefixed.
    NSData *compressedData = rawData;
    if ([Arq7EncryptedObjectDecryptor isEncryptedData:rawData]) {
        if (theKeySet == nil) {
            SETNSERROR(@"Arq6SnapshotErrorDomain", ERROR_INVALID_PASSWORD,
                       @"snapshot is encrypted but no key set provided");
            return nil;
        }
        Arq7EncryptedObjectDecryptor *dec = [[Arq7EncryptedObjectDecryptor alloc] initWithKeySet:theKeySet];
        compressedData = [dec decryptData:rawData error:error];
        if (compressedData == nil) {
            return nil;
        }
    }

    // Step 2: LZ4-decompress. Format: 4-byte big-endian original size + LZ4 block.
    if ([compressedData length] < 5) {
        SETNSERROR(@"Arq6SnapshotErrorDomain", -1, @"snapshot data too short for LZ4");
        return nil;
    }
    const unsigned char *compBytes = (const unsigned char *)[compressedData bytes];
    uint32_t nboSize = 0;
    memcpy(&nboSize, compBytes, 4);
    int originalSize = (int)OSSwapBigToHostInt32(nboSize);
    if (originalSize < 0 || originalSize > 64 * 1024 * 1024) {
        SETNSERROR(@"Arq6SnapshotErrorDomain", -1,
                   @"invalid LZ4 original size in snapshot: %d", originalSize);
        return nil;
    }

    NSMutableData *jsonData = [NSMutableData dataWithLength:(NSUInteger)originalSize];
    int compressedSize = (int)[compressedData length] - 4;
    int inflated = LZ4_decompress_safe((const char *)(compBytes + 4),
                                       (char *)[jsonData mutableBytes],
                                       compressedSize,
                                       originalSize);
    if (inflated != originalSize) {
        SETNSERROR(@"Arq6SnapshotErrorDomain", -1,
                   @"LZ4 decompression failed for snapshot (got %d, expected %d)",
                   inflated, originalSize);
        return nil;
    }

    // Step 3: parse as JSON.
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:error];
    if (json == nil) {
        return nil;
    }

    return [[Arq6Snapshot alloc] initWithJSON:json error:error];
}

- (instancetype)initWithJSON:(NSDictionary *)theJSON error:(NSError **)error {
    if (self = [super init]) {
        id dateVal = [theJSON objectForKey:@"creationDate"];
        if (dateVal != nil) {
            _creationDate = [NSDate dateWithTimeIntervalSince1970:[dateVal doubleValue]];
        }
        _isComplete = [[theJSON objectForKey:@"isComplete"] boolValue];
        _planUUID = [theJSON objectForKey:@"planUUID"];

        NSDictionary *svsByDiskIdentifierJSON = [theJSON objectForKey:@"snapshotVolumesByDiskIdentifier"];
        NSMutableDictionary *volumes = [NSMutableDictionary dictionary];
        for (NSString *diskIdentifier in [svsByDiskIdentifierJSON allKeys]) {
            NSDictionary *svJSON = [svsByDiskIdentifierJSON objectForKey:diskIdentifier];
            NSDictionary *nodeJSON = [svJSON objectForKey:@"node"];
            if (nodeJSON == nil) {
                continue;
            }
            Arq7Node *node = [[Arq7Node alloc] initWithJSON:nodeJSON error:error];
            if (node == nil) {
                return nil;
            }
            NSString *name = [svJSON objectForKey:@"name"] ?: @"";
            NSString *mountPoint = [svJSON objectForKey:@"mountPoint"] ?: @"";
            Arq6SnapshotVolume *vol = [[Arq6SnapshotVolume alloc] initWithDiskIdentifier:diskIdentifier
                                                                                    name:name
                                                                              mountPoint:mountPoint
                                                                                    node:node];
            [volumes setObject:vol forKey:diskIdentifier];
        }
        _volumesByDiskIdentifier = volumes;
    }
    return self;
}

- (NSDate *)creationDate { return _creationDate; }
- (BOOL)isComplete { return _isComplete; }
- (NSString *)planUUID { return _planUUID; }
- (NSDictionary *)volumesByDiskIdentifier { return _volumesByDiskIdentifier; }
@end
