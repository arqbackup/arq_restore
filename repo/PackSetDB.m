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




#include <sys/types.h>
#include <sys/stat.h>
#import "PackSetDB.h"
#import "UserLibrary_Arq.h"
#import "NSFileManager_extra.h"
#import "FMDB.h"
#import "PackId.h"
#import "PackIndexEntry.h"
#import "FlockFile.h"
#import "CacheOwnership.h"


@implementation PackSetDB
+ (NSString *)errorDomain {
    return @"PackSetDBErrorDomain";
}

- (id)initWithTargetUUID:(NSString *)theTargetUUID computerUUID:(NSString *)theComputerUUID packSetName:(NSString *)thePackSetName error:(NSError **)error {
    if (self = [super init]) {
        dbPath = [[NSString alloc] initWithFormat:@"%@/%@/%@/packsets/%@.db", [UserLibrary arqCachePath], theTargetUUID, theComputerUUID, thePackSetName];
        lockFilePath = [[dbPath stringByAppendingString:@".lock"] retain];
        if (![[NSFileManager defaultManager] ensureParentPathExistsForPath:dbPath targetUID:[[CacheOwnership sharedCacheOwnership] uid] targetGID:[[CacheOwnership sharedCacheOwnership] gid] error:error]) {
            [self release];
            return nil;
        }
        
        NSError *myError = nil;
        fmdbq = [[self initDB:&myError] retain];
        if (fmdbq == nil) {
            HSLogError(@"failed to open packset cache database %@: %@", dbPath, myError);
            if ([myError isErrorWithDomain:[PackSetDB errorDomain] code:SQLITE_CORRUPT]) {
                // Delete the file.
                HSLogInfo(@"deleting corrupt packset cache database %@", dbPath);
                if (![[NSFileManager defaultManager] removeItemAtPath:dbPath error:&myError]) {
                    HSLogError(@"failed to delete corrupt sqlite database %@: %@", dbPath, myError);
                }
                fmdbq = [[self initDB:&myError] retain];
            }
        }
        if (fmdbq == nil) {
            SETERRORFROMMYERROR;
            [self release];
            return nil;
        }
    }
    return self;
}
- (void)dealloc {
    [fmdbq close];
    [fmdbq release];
    [dbPath release];
    [lockFilePath release];
    [super dealloc];
}

- (NSSet *)packIds:(NSError **)error {
    FlockFile *ff = [[[FlockFile alloc] initWithPath:lockFilePath] autorelease];
    __block NSSet *ret = nil;
    if (![ff lockAndExecute:^void() { ret = [self lockedPackIds:error]; } error:error]) {
        ret = nil;
    }
    return ret;
}
- (PackId *)firstPackIdWithPackSizeBelow:(NSUInteger)theMaxSize error:(NSError **)error {
    FlockFile *ff = [[[FlockFile alloc] initWithPath:lockFilePath] autorelease];
    __block PackId *ret = nil;
    if (![ff lockAndExecute:^void() { ret = [self lockedFirstPackIdWithPackSizeBelow:theMaxSize error:error]; } error:error]) {
        ret = nil;
    }
    return ret;
}
- (NSNumber *)containsPackId:(PackId *)thePackId error:(NSError **)error {
    FlockFile *ff = [[[FlockFile alloc] initWithPath:lockFilePath] autorelease];
    __block NSNumber *ret = nil;
    if (![ff lockAndExecute:^void() { ret = [self lockedIsStoredForPackId:thePackId error:error]; } error:error]) {
        ret = nil;
    }
    return ret;
}
- (BOOL)insertPackId:(PackId *)thePackId packIndexEntries:(NSArray *)thePIES error:(NSError **)error {
    HSLogDetail(@"inserting %@ entries into cache db (%ld entries)", thePackId, (unsigned long)[thePIES count]);
    FlockFile *ff = [[[FlockFile alloc] initWithPath:lockFilePath] autorelease];
    __block BOOL ret = NO;
    if (![ff lockAndExecute:^void() { ret = [self lockedInsertPackId:thePackId packIndexEntries:thePIES error:error]; } error:error]) {
        ret = NO;
    }
    return ret;
}
- (BOOL)deletePackId:(PackId *)thePackId error:(NSError **)error {
    HSLogDetail(@"deleting entries from cache db for %@", thePackId);
    FlockFile *ff = [[[FlockFile alloc] initWithPath:lockFilePath] autorelease];
    __block BOOL ret = NO;
    if (![ff lockAndExecute:^void() { ret = [self lockedDeletePackId:thePackId error:error]; } error:error]) {
        ret = NO;
    }
    return ret;
}
- (PackIndexEntry *)packIndexEntryForSHA1:(NSString *)theSHA1 error:(NSError **)error {
    FlockFile *ff = [[[FlockFile alloc] initWithPath:lockFilePath] autorelease];
    __block PackIndexEntry *ret = nil;
    if (![ff lockAndExecute:^void() { ret = [self lockedPackIndexEntryForSHA1:theSHA1 error:error]; } error:error]) {
        ret = nil;
    }
    return ret;
}


#pragma mark internal
- (NSSet *)lockedPackIds:(NSError **)error {
    __block NSMutableSet *ret = nil;
    
    [fmdbq inDatabase:^(FMDatabase *db) {
//        HSLogDebug(@"querying for pack ids");
//        NSTimeInterval theTime = [NSDate timeIntervalSinceReferenceDate];
        FMResultSet *rs = [db executeQuery:@"SELECT pack_set_name, pack_sha1 FROM packs"];
//        HSLogDebug(@"query for pack ids took %0.2f seconds", ([NSDate timeIntervalSinceReferenceDate] - theTime));
        if (rs == nil) {
            SETNSERROR([PackSetDB errorDomain], [db lastErrorCode], @"SELECT pack_set_name, pack_sha1 FROM packs: %@", [db lastErrorMessage]);
            return;
        }
        ret = [NSMutableSet set];
        while ([rs next]) {
            NSString *packSetName = [rs stringForColumnIndex:0];
            NSString *packSHA1 = [rs stringForColumnIndex:1];
            [ret addObject:[[[PackId alloc] initWithPackSetName:packSetName packSHA1:packSHA1] autorelease]];
        }
        [rs close];
    }];
    
    return ret;
}
- (PackId *)lockedFirstPackIdWithPackSizeBelow:(NSUInteger)theMaxSize error:(NSError **)error {
    __block PackId *ret = nil;
    
    [fmdbq inDatabase:^(FMDatabase *db) {
//        HSLogDebug(@"querying for pack ids by size");
//        NSTimeInterval theTime = [NSDate timeIntervalSinceReferenceDate];
        FMResultSet *rs = [db executeQuery:@"SELECT MAX(offset+length) size, pack_sha1 FROM pack_index_entries GROUP BY pack_sha1 ORDER BY size"];
//        HSLogDebug(@"query for pack ids by size took %0.2f seconds", ([NSDate timeIntervalSinceReferenceDate] - theTime));
        if (rs == nil) {
            SETNSERROR([PackSetDB errorDomain], [db lastErrorCode], @"db select pack sizes: %@", [db lastErrorMessage]);
            return;
        }
        if (![rs next]) {
            SETNSERROR([PackSetDB errorDomain], ERROR_NOT_FOUND, @"no packs found with size below %ld", (unsigned long)theMaxSize);
            [rs close];
            return;
        }
        int size = [rs intForColumnIndex:0];
        NSString *packSHA1 = [rs stringForColumnIndex:1];
        [rs close];

        HSLogDebug(@"smallest pack size found: packSHA1=%@, size=%d", packSHA1, size);
        if (size > theMaxSize) {
            SETNSERROR([PackSetDB errorDomain], ERROR_NOT_FOUND, @"no packs found with size below %ld", (unsigned long)theMaxSize);
            return;
        }
        
//        HSLogDebug(@"querying for pack set name");
//        theTime = [NSDate timeIntervalSinceReferenceDate];
        rs = [db executeQuery:@"SELECT pack_set_name FROM packs WHERE pack_sha1 = ?" withArgumentsInArray:[NSArray arrayWithObject:packSHA1]];
//        HSLogDebug(@"query for pack set name took %0.2f seconds", ([NSDate timeIntervalSinceReferenceDate] - theTime));
        if (rs == nil) {
            SETNSERROR([PackSetDB errorDomain], [db lastErrorCode], @"db select pack_set_name: %@", [db lastErrorMessage]);
            return;
        }
        if (![rs next]) {
            SETNSERROR([PackSetDB errorDomain], -1, @"pack_sha1 %@ not found in packs table", packSHA1);
            [rs close];
            return;
        }
        NSString *packSetName = [rs stringForColumnIndex:0];
        [rs close];
        ret = [[[PackId alloc] initWithPackSetName:packSetName packSHA1:packSHA1] autorelease];
    }];

    if (ret != nil) {
        HSLogDebug(@"found pack smaller than %ld bytes: %@", theMaxSize, ret);
    }
    return ret;
}
- (NSNumber *)lockedIsStoredForPackId:(PackId *)thePackId error:(NSError **)error {
    __block NSNumber *ret = nil;
    
    [fmdbq inDatabase:^(FMDatabase *db) {
//        HSLogDebug(@"querying for pack %@", [thePackId packSHA1]);
//        NSTimeInterval theTime = [NSDate timeIntervalSinceReferenceDate];
        FMResultSet *rs = [db executeQuery:@"SELECT pack_set_name, pack_sha1 FROM packs WHERE pack_sha1 = ?" withArgumentsInArray:[NSArray arrayWithObject:[thePackId packSHA1]]];
//        HSLogDebug(@"query for pack %@ took %0.2f seconds", [thePackId packSHA1], ([NSDate timeIntervalSinceReferenceDate] - theTime));
        if (rs == nil) {
            SETNSERROR([PackSetDB errorDomain], [db lastErrorCode], @"db select from packs: %@", [db lastErrorMessage]);
            return;
        }
        
        ret = [NSNumber numberWithBool:[rs next]];
        [rs close];
    }];

    return ret;
}
- (BOOL)lockedInsertPackId:(PackId *)thePackId packIndexEntries:(NSArray *)thePIEs error:(NSError **)error {
    __block BOOL ret = NO;
    
    [fmdbq inDatabase:^(FMDatabase *db) {
        db.logsErrors = YES;
        if (![db open]) {
            SETNSERROR([PackSetDB errorDomain], [db lastErrorCode], @"open db(%@): error=%@, db=%@", dbPath, [db lastErrorMessage], dbPath);
            return;
        }
        // Begin transaction.
        if (![db beginTransaction]) {
            SETNSERROR([PackSetDB errorDomain], [db lastErrorCode], @"begin transaction in storePackIndexEntries failed: %@", [db lastErrorMessage]);
            return;
        }
        
        ret = [self doLockedInsertPackId:thePackId packIndexEntries:thePIEs database:db error:error];
        
        // Commit.
        if (ret) {
            if (![db commit]) {
                SETNSERROR([PackSetDB errorDomain], [db lastErrorCode], @"commit in storePackIndexEntries failed: %@", [db lastErrorMessage]);
                ret = NO;
                return;
            }
        } else {
            [db rollback];
        }
    }];
    
    return ret;
}

- (BOOL)doLockedInsertPackId:(PackId *)thePackId packIndexEntries:(NSArray *)thePIEs database:(FMDatabase *)db error:(NSError **)error {
    // Delete any existing data.
    if (![db executeUpdate:@"DELETE FROM packs WHERE pack_sha1 = ?" withArgumentsInArray:[NSArray arrayWithObject:[thePackId packSHA1]]]) {
        SETNSERROR([PackSetDB errorDomain], [db lastErrorCode], @"delete from packs error: %@", [db lastErrorMessage]);
        return NO;
    }
    if (![db executeUpdate:@"DELETE FROM pack_index_entries WHERE pack_sha1 = ?" withArgumentsInArray:[NSArray arrayWithObject:[thePackId packSHA1]]]) {
        SETNSERROR([PackSetDB errorDomain], [db lastErrorCode], @"delete from pack_index_entries error: %@", [db lastErrorMessage]);
        return NO;
    }
    
    // Delete existing pack_index_entries if any and insert new pack_index_entries.
    for (PackIndexEntry *pie in thePIEs) {
        if (![db executeUpdate:@"DELETE FROM pack_index_entries WHERE object_sha1 = ?" withArgumentsInArray:[NSArray arrayWithObject:[pie objectSHA1]]]) {
            SETNSERROR([PackSetDB errorDomain], [db lastErrorCode], @"delete from pack_index_entries for object error: %@", [db lastErrorMessage]);
            return NO;
        }
        NSArray *args = [NSArray arrayWithObjects:[pie objectSHA1],
                         [thePackId packSHA1],
                         [NSNumber numberWithUnsignedLongLong:[pie offset]],
                         [NSNumber numberWithUnsignedLongLong:[pie dataLength]],
                         nil];
        if (![db executeUpdate:@"INSERT INTO pack_index_entries (object_sha1, pack_sha1, offset, length) VALUES (?, ?, ?, ?)" withArgumentsInArray:args]) {
            SETNSERROR([PackSetDB errorDomain], [db lastErrorCode], @"insert into pack_index_entries error: %@", [db lastErrorMessage]);
            return NO;
        }
    }
    
    // Insert new pack.
    NSArray *args = [NSArray arrayWithObjects:[thePackId packSHA1], [thePackId packSetName], nil];
    if (![db executeUpdate:@"INSERT INTO packs (pack_sha1, pack_set_name) VALUES (?, ?)" withArgumentsInArray:args]) {
        SETNSERROR([PackSetDB errorDomain], [db lastErrorCode], @"insert into packs error: %@", [db lastErrorMessage]);
        return NO;
    }
    return YES;
}
- (PackIndexEntry *)lockedPackIndexEntryForSHA1:(NSString *)theSHA1 error:(NSError **)error {
    if (theSHA1 == nil) {
        SETNSERROR([PackSetDB errorDomain], -1, @"packIndexEntryForSHA1: sha1 is nil");
        return nil;
    }
    if ([theSHA1 length] == 0) {
        SETNSERROR([PackSetDB errorDomain], -1, @"packIndexEntryForSHA1: invalid sha1 '%@'", theSHA1);
        return nil;
    }
    
    __block PackIndexEntry *ret = nil;
    
    [fmdbq inDatabase:^(FMDatabase *db) {
//        HSLogDebug(@"querying for pack index entry for %@", theSHA1);
//        NSTimeInterval theTime = [NSDate timeIntervalSinceReferenceDate];
        FMResultSet *rs = [db executeQuery:@"SELECT pie.object_sha1 object_sha1, pie.pack_sha1 pack_sha1, pie.offset offset, pie.length length, p.pack_set_name pack_set_name FROM pack_index_entries pie, packs p WHERE pie.pack_sha1 = p.pack_sha1 and pie.object_sha1 = ?" withArgumentsInArray:[NSArray arrayWithObject:theSHA1]];
//        HSLogDebug(@"query for pack index entry for %@ took %0.2f seconds", theSHA1, ([NSDate timeIntervalSinceReferenceDate] - theTime));
        if (rs == nil) {
            SETNSERROR([PackSetDB errorDomain], [db lastErrorCode], @"select pack index entry failed: %@", [db lastErrorMessage]);
            return;
        }
        if (![rs next]) {
            SETNSERROR([PackSetDB errorDomain], ERROR_NOT_FOUND, @"pack index entry not found for %@", theSHA1);
            [rs close];
            return;
        }
        
        NSString *objectSHA1 = [rs stringForColumnIndex:0];
        NSString *packSHA1 = [rs stringForColumnIndex:1];
        unsigned long long offset = (unsigned long long)[rs intForColumnIndex:2];
        unsigned long long length = (unsigned long long)[rs intForColumnIndex:3];
        NSString *packSetName = [rs stringForColumnIndex:4];
        [rs close];
        
        PackId *packId = [[[PackId alloc] initWithPackSetName:packSetName packSHA1:packSHA1] autorelease];
        ret = [[[PackIndexEntry alloc] initWithPackId:packId offset:offset dataLength:length objectSHA1:objectSHA1] autorelease];
    }];

    return ret;
}
- (BOOL)lockedDeletePackId:(PackId *)thePackId error:(NSError **)error {
    __block BOOL ret = YES;
    
    [fmdbq inDatabase:^(FMDatabase *db) {
        if (![db beginTransaction]) {
            ret = NO;
            SETNSERROR([PackSetDB errorDomain], [db lastErrorCode], @"begin transaction in replacePackIndexEntries failed: %@", [db lastErrorMessage]);
            return;
        }
        ret = [self doLockedDeletePackId:thePackId db:db error:error];
        
        // Commit.
        if (ret) {
            if (![db commit]) {
                SETNSERROR([PackSetDB errorDomain], [db lastErrorCode], @"commit in replacePackIndexEntries failed: %@", [db lastErrorMessage]);
                ret = NO;
                return;
            }
        } else {
            [db rollback];
        }
    }];

    return ret;
}

- (BOOL)doLockedDeletePackId:(PackId *)thePackId db:(FMDatabase *)db error:(NSError **)error {
    // Delete all existing pack_index_entries.
    if (![db executeUpdate:@"DELETE FROM pack_index_entries WHERE pack_sha1 = ?" withArgumentsInArray:[NSArray arrayWithObject:[thePackId packSHA1]]]) {
        SETNSERROR([PackSetDB errorDomain], [db lastErrorCode], @"delete pack_index_entries for pack error: %@", [db lastErrorMessage]);
        return NO;
    }
    
    // Delete old pack.
    if (![db executeUpdate:@"DELETE FROM packs WHERE pack_sha1 = ?" withArgumentsInArray:[NSArray arrayWithObject:[thePackId packSHA1]]]) {
        SETNSERROR([PackSetDB errorDomain], [db lastErrorCode], @"delete from packs error: %@", [db lastErrorMessage]);
        return NO;
    }
    
    return YES;
}

- (FMDatabaseQueue *)initDB:(NSError **)error {
    FlockFile *ff = [[[FlockFile alloc] initWithPath:lockFilePath] autorelease];
    __block FMDatabaseQueue *ret = nil;
    if (![ff lockAndExecute:^void() { ret = [self lockedInitDB:error]; } error:error]) {
        ret = nil;
    }
    return ret;
}
- (FMDatabaseQueue *)lockedInitDB:(NSError **)error {
    if (![[NSFileManager defaultManager] ensureParentPathExistsForPath:dbPath targetUID:[[CacheOwnership sharedCacheOwnership] uid] targetGID:[[CacheOwnership sharedCacheOwnership] gid] error:error]) {
        return nil;
    }
    
    __block BOOL ret = NO;
    
    FMDatabaseQueue *dbq = [FMDatabaseQueue databaseQueueWithPath:dbPath];
    [dbq inDatabase:^(FMDatabase *db) {
        db.logsErrors = YES;
        if (![db open]) {
            SETNSERROR([PackSetDB errorDomain], [db lastErrorCode], @"open db(%@): error=%@, db=%@", dbPath, [db lastErrorMessage], dbPath);
            return;
        }
        if (chmod([dbPath fileSystemRepresentation], S_IRUSR|S_IWUSR|S_IRGRP|S_IWGRP|S_IROTH|S_IWOTH) < 0) {
            int errnum = errno;
            HSLogError(@"chmod(%@) error %d: %s", dbPath, errnum, strerror(errnum));
        }
        if (chown([dbPath fileSystemRepresentation], [[CacheOwnership sharedCacheOwnership] uid], [[CacheOwnership sharedCacheOwnership] gid]) == -1) {
            int errnum = errno;
            SETNSERROR(@"UnixErrorDomain", errnum, @"chown(%@, %d, %d): %s", dbPath, [[CacheOwnership sharedCacheOwnership] uid], [[CacheOwnership sharedCacheOwnership] gid], strerror(errnum));
            return;
        }
        
        if (![db executeUpdate:@"CREATE TABLE IF NOT EXISTS packs (pack_sha1 TEXT NOT NULL PRIMARY KEY, pack_set_name TEXT NOT NULL)"]
            || ![db executeUpdate:@"CREATE TABLE IF NOT EXISTS pack_index_entries (object_sha1 TEXT NOT NULL PRIMARY KEY, pack_sha1 TEXT NOT NULL, offset INTEGER NOT NULL, length INTEGER NOT NULL)"]) {
            SETNSERROR([PackSetDB errorDomain], [db lastErrorCode], @"db create table: %@", [db lastErrorMessage]);
            return;
        }
        [db setShouldCacheStatements:YES];
        
        if ([self schemaVersion] == 0) {
            if (![db executeUpdate:@"CREATE INDEX pack_index_entries_pack_sha1 ON pack_index_entries (pack_sha1)"]) {
                SETNSERROR([PackSetDB errorDomain], [db lastErrorCode], @"db create index pack_index_entries_pack_sha1: error=%@, db=%@", [db lastErrorMessage], dbPath);
                return;
            }
            if (![self setSchemaVersion:1 error:error]) {
                return;
            }
        }
        
        ret = YES;
    }];
    if (!ret) {
        return nil;
    }
    
    return dbq;
}

- (int)schemaVersion {
    __block int ret = 0;
    
    FMDatabaseQueue *dbq = [FMDatabaseQueue databaseQueueWithPath:dbPath];
    [dbq inDatabase:^(FMDatabase *db) {
        if (![db tableExists:@"packset_schema"]) {
            if (![db executeUpdate:@"CREATE TABLE IF NOT EXISTS packset_schema (version INTEGER NOT NULL PRIMARY KEY)"]) {
                HSLogError(@"db create table: error=%@, db=%@", [db lastErrorMessage], dbPath);
                return;
            }
        }
        
        FMResultSet *rs = [db executeQuery:@"SELECT version FROM packset_schema" withArgumentsInArray:[NSArray array]];
        if (rs == nil) {
            HSLogError(@"db select version: error=%@, db=%@", [db lastErrorMessage], dbPath);
            return;
        }
        if (![rs next]) {
            if (![db executeUpdate:@"INSERT INTO packset_schema VALUES (0)"]) {
                HSLogError(@"db insert into packset_schema: error=%@, db=%@", [db lastErrorMessage], dbPath);
                return;
            }
        } else {
            ret = [rs intForColumn:@"version"];
        }
        [rs close];
    }];
    return ret;
}
- (BOOL)setSchemaVersion:(int)theSchemaVersion error:(NSError **)error {
    int currentVersion = [self schemaVersion]; // This creates the table too, if necessary.
    HSLogDebug(@"updating packset_schema version from %d to %d", currentVersion, theSchemaVersion);
    
    __block BOOL ret = NO;
    FMDatabaseQueue *dbq = [FMDatabaseQueue databaseQueueWithPath:dbPath];
    [dbq inDatabase:^(FMDatabase *db) {
        if (![db executeUpdate:@"UPDATE packset_schema SET version = ?" withArgumentsInArray:[NSArray arrayWithObject:[NSNumber numberWithInt:theSchemaVersion]]]) {
            SETNSERROR([PackSetDB errorDomain], [db lastErrorCode], @"db update packset_schema: error=%@, db=%@", [db lastErrorMessage], dbPath);
            return;
        }
        ret = YES;
    }];
    
    return ret;
}


#pragma mark NSObject
- (NSString *)description {
    return [NSString stringWithFormat:@"<PackSetDB %@>", dbPath];
}
@end
