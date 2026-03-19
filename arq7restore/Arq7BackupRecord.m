#import "Arq7BackupRecord.h"
#import "Arq7KeySet.h"
#import "Arq7EncryptedObjectDecryptor.h"
#import "Arq7Node.h"
#import "TargetConnection.h"
#import "Item.h"
#include "lz4.h"
#include <libkern/OSByteOrder.h>


@interface Arq7BackupRecord() {
    int _version;
    NSString *_localPath;
    NSString *_backupFolderUUID;
    NSString *_backupPlanUUID;
    NSDate *_creationDate;
    BOOL _isComplete;
    Arq7Node *_node;
}
@end


@implementation Arq7BackupRecord

- (NSString *)errorDomain {
    return @"Arq7BackupRecordErrorDomain";
}

+ (Arq7BackupRecord *)mostRecentBackupRecordForPlanUUID:(NSString *)thePlanUUID
                                             folderUUID:(NSString *)theFolderUUID
                                       targetConnection:(TargetConnection *)theConn
                                                 keySet:(Arq7KeySet *)theKeySet
                                               delegate:(id <TargetConnectionDelegate>)theDelegate
                                                  error:(NSError **)error {
    NSString *backupRecordsPath = [NSString stringWithFormat:@"/%@/backupfolders/%@/backuprecords",
                                   thePlanUUID, theFolderUUID];

    // List 5-digit subdirectories.
    NSDictionary *dirsByName = [theConn itemsByNameAtPath:backupRecordsPath
                                targetConnectionDelegate:theDelegate
                                                   error:error];
    if (dirsByName == nil) {
        return nil;
    }

    // Sort newest first (lexicographic sort = newest dir last, so we reverse).
    NSArray *sortedDirNames = [[dirsByName allKeys] sortedArrayUsingSelector:@selector(compare:)];
    for (NSString *dirName in [sortedDirNames reverseObjectEnumerator]) {
        if ([dirName isEqualToString:@".DS_Store"] || [dirName isEqualToString:@"@eaDir"]) {
            continue;
        }
        Item *dirItem = [dirsByName objectForKey:dirName];
        if (![dirItem isDirectory]) {
            continue;
        }

        NSString *subDir = [backupRecordsPath stringByAppendingPathComponent:dirName];
        NSDictionary *recordsByName = [theConn itemsByNameAtPath:subDir
                                        targetConnectionDelegate:theDelegate
                                                           error:error];
        if (recordsByName == nil) {
            return nil;
        }

        NSArray *sortedRecordNames = [[recordsByName allKeys] sortedArrayUsingSelector:@selector(compare:)];
        for (NSString *recordName in [sortedRecordNames reverseObjectEnumerator]) {
            if ([recordName isEqualToString:@".DS_Store"] || [recordName isEqualToString:@"@eaDir"]) {
                continue;
            }
            NSString *recordPath = [subDir stringByAppendingPathComponent:recordName];
            NSError *myError = nil;
            Arq7BackupRecord *record = [Arq7BackupRecord backupRecordAtPath:recordPath
                                                           targetConnection:theConn
                                                                     keySet:theKeySet
                                                                   delegate:theDelegate
                                                                      error:&myError];
            if (record == nil) {
                HSLogError(@"failed to read backup record %@: %@", recordPath, myError);
                continue;
            }
            if (record.isComplete) {
                return record;
            }
        }
    }

    SETNSERROR(@"Arq7BackupRecordErrorDomain", ERROR_NOT_FOUND,
               @"no complete backup record found for plan %@ folder %@", thePlanUUID, theFolderUUID);
    return nil;
}

+ (Arq7BackupRecord *)backupRecordAtPath:(NSString *)thePath
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
            SETNSERROR(@"Arq7BackupRecordErrorDomain", ERROR_INVALID_PASSWORD, @"backup record is encrypted but no key set provided");
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
        SETNSERROR(@"Arq7BackupRecordErrorDomain", -1, @"backup record data too short for LZ4");
        return nil;
    }
    const unsigned char *compBytes = (const unsigned char *)[compressedData bytes];
    uint32_t nboSize = 0;
    memcpy(&nboSize, compBytes, 4);
    int originalSize = (int)OSSwapBigToHostInt32(nboSize);
    if (originalSize < 0 || originalSize > 64 * 1024 * 1024) {
        SETNSERROR(@"Arq7BackupRecordErrorDomain", -1, @"invalid LZ4 original size in backup record: %d", originalSize);
        return nil;
    }

    NSMutableData *jsonData = [NSMutableData dataWithLength:(NSUInteger)originalSize];
    int compressedSize = (int)[compressedData length] - 4;
    int inflated = LZ4_decompress_safe((const char *)(compBytes + 4),
                                       (char *)[jsonData mutableBytes],
                                       compressedSize,
                                       originalSize);
    if (inflated != originalSize) {
        SETNSERROR(@"Arq7BackupRecordErrorDomain", -1, @"LZ4 decompression failed for backup record (got %d, expected %d)", inflated, originalSize);
        return nil;
    }

    // Step 3: parse as JSON.
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:error];
    if (json == nil) {
        return nil;
    }

    return [[Arq7BackupRecord alloc] initWithJSON:json error:error];
}

- (instancetype)initWithJSON:(NSDictionary *)theJSON error:(NSError **)error {
    if (self = [super init]) {
        _version = [[theJSON objectForKey:@"version"] intValue];
        _localPath = [theJSON objectForKey:@"localPath"];
        _backupFolderUUID = [theJSON objectForKey:@"backupFolderUUID"];
        _backupPlanUUID = [theJSON objectForKey:@"backupPlanUUID"];
        _isComplete = [[theJSON objectForKey:@"isComplete"] boolValue];

        // Parse creationDate (seconds since epoch stored as a number).
        id dateVal = [theJSON objectForKey:@"creationDate"];
        if (dateVal != nil) {
            _creationDate = [NSDate dateWithTimeIntervalSince1970:[dateVal doubleValue]];
        }

        // Parse root node (version 100 only).
        NSDictionary *nodeJSON = [theJSON objectForKey:@"node"];
        if (nodeJSON != nil) {
            _node = [[Arq7Node alloc] initWithJSON:nodeJSON error:error];
            if (_node == nil) {
                return nil;
            }
        }
    }
    return self;
}

- (int)version { return _version; }
- (NSString *)localPath { return _localPath; }
- (NSString *)backupFolderUUID { return _backupFolderUUID; }
- (NSString *)backupPlanUUID { return _backupPlanUUID; }
- (NSDate *)creationDate { return _creationDate; }
- (BOOL)isComplete { return _isComplete; }
- (Arq7Node *)node { return _node; }
@end
