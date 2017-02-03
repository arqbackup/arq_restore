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
#import "sqlite3.h"
#import "TargetItemsDB.h"
#import "NSFileManager_extra.h"
#import "ItemsDB.h"
#import "FMDB.h"
#import "UserLibrary_Arq.h"
#import "Item.h"
#import "NSString_extra.h"
#import "CacheOwnership.h"
#import "FlockFile.h"
#import "FMDatabaseAdditions.h"
#import "NSString_slashed.h"


@implementation TargetItemsDB
- (id)initWithTargetUUID:(NSString *)theTargetUUID error:(NSError **)error {
    if (self = [super init]) {
        dbPath = [[[[UserLibrary arqCachePath] stringByAppendingPathComponent:theTargetUUID] stringByAppendingPathComponent:@"items.db"] retain];
        lockFilePath = [[dbPath stringByAppendingString:@".lock"] retain];
        if (![[NSFileManager defaultManager] ensureParentPathExistsForPath:dbPath targetUID:[[CacheOwnership sharedCacheOwnership] uid] targetGID:[[CacheOwnership sharedCacheOwnership] gid] error:error]) {
            [self release];
            return nil;
        }
        
        NSError *myError = nil;
        fmdbq = [[self initDB:&myError] retain];
        if (fmdbq == nil) {
            HSLogError(@"failed to open items cache database %@: %@", dbPath, myError);
            if ([myError isErrorWithDomain:[ItemsDB errorDomain] code:SQLITE_CORRUPT]) {
                // Delete the file.
                HSLogInfo(@"deleting corrupt items cache database %@", dbPath);
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

- (Item *)itemAtPath:(NSString *)thePath error:(NSError **)error {
    FlockFile *ff = [[[FlockFile alloc] initWithPath:lockFilePath] autorelease];
    __block Item *ret = nil;
    if (![ff lockAndExecute:^void() { ret = [self lockedItemAtPath:thePath error:error]; } error:error]) {
        ret = nil;
    }
    return ret;
}
- (NSNumber *)cacheIsLoadedForDirectory:(NSString *)theDirectory error:(NSError **)error {
    // Don't get a flockfile first for performance reasons.
    
    __block NSNumber *ret = nil;

    [fmdbq inDatabase:^(FMDatabase *db) {
        ret = [self isLoadedForDirectory:theDirectory db:db error:error];
    }];

    return ret;
}
- (NSMutableDictionary *)itemsByNameInDirectory:(NSString *)theDirectory error:(NSError **)error {
    FlockFile *ff = [[[FlockFile alloc] initWithPath:lockFilePath] autorelease];
    __block NSMutableDictionary *ret = nil;
    if (![ff lockAndExecute:^void() { ret = [self lockedItemsByNameInDirectory:theDirectory error:error]; } error:error]) {
        ret = nil;
    }
    return ret;
}
- (BOOL)setItemsByName:(NSDictionary *)theItemsByName inDirectory:(NSString *)theDirectory error:(NSError **)error {
    FlockFile *ff = [[[FlockFile alloc] initWithPath:lockFilePath] autorelease];
    __block BOOL ret = NO;
    if (![ff lockAndExecute:^void() { ret = [self lockedSetItemsByName:theItemsByName inDirectory:theDirectory error:error]; } error:error]) {
        ret = NO;
    }
    return ret;
}

- (BOOL)clearItemsByNameInDirectory:(NSString *)theDirectory error:(NSError **)error {
    FlockFile *ff = [[[FlockFile alloc] initWithPath:lockFilePath] autorelease];
    __block BOOL ret = NO;
    if (![ff lockAndExecute:^void() { ret = [self lockedClearItemsByNameInDirectory:theDirectory error:error]; } error:error]) {
        ret = NO;
    }
    return ret;
}
- (BOOL)destroy:(NSError **)error {
    FlockFile *ff = [[[FlockFile alloc] initWithPath:lockFilePath] autorelease];
    __block BOOL ret = NO;
    if (![ff lockAndExecute:^void() { ret = [self lockedDestroy:error]; } error:error]) {
        ret = NO;
    }
    return ret;
}

- (BOOL)addItem:(Item *)theItem inDirectory:(NSString *)theDirectory error:(NSError **)error {
    FlockFile *ff = [[[FlockFile alloc] initWithPath:lockFilePath] autorelease];
    __block BOOL ret = NO;
    if (![ff lockAndExecute:^void() { ret = [self lockedAddItem:theItem inDirectory:theDirectory error:error]; } error:error]) {
        ret = NO;
    }
    return ret;
}
- (BOOL)addOrReplaceItem:(Item *)theItem inDirectory:(NSString *)theDirectory error:(NSError **)error {
    FlockFile *ff = [[[FlockFile alloc] initWithPath:lockFilePath] autorelease];
    __block BOOL ret = NO;
    if (![ff lockAndExecute:^void() { ret = [self lockedAddOrReplaceItem:theItem inDirectory:theDirectory error:error]; } error:error]) {
        ret = NO;
    }
    return ret;
}
- (BOOL)removeItemWithName:(NSString *)theItemName inDirectory:(NSString *)theDirectory error:(NSError **)error {
    FlockFile *ff = [[[FlockFile alloc] initWithPath:lockFilePath] autorelease];
    __block BOOL ret = NO;
    if (![ff lockAndExecute:^void() { ret = [self lockedRemoveItemWithName:theItemName inDirectory:theDirectory error:error]; } error:error]) {
        ret = NO;
    }
    return ret;
}
- (BOOL)moveItem:(Item *)theItem fromDirectory:(NSString *)theFromDirectory toDirectory:(NSString *)theToDirectory error:(NSError **)error {
    FlockFile *ff = [[[FlockFile alloc] initWithPath:lockFilePath] autorelease];
    __block BOOL ret = NO;
    if (![ff lockAndExecute:^void() { ret = [self lockedMoveItem:theItem fromDirectory:theFromDirectory toDirectory:theToDirectory error:error]; } error:error]) {
        ret = NO;
    }
    return ret;
}
- (BOOL)clearReferenceCounts:(NSError **)error {
    FlockFile *ff = [[[FlockFile alloc] initWithPath:lockFilePath] autorelease];
    __block BOOL ret = NO;
    if (![ff lockAndExecute:^void() { ret = [self lockedClearReferenceCounts:error]; } error:error]) {
        ret = NO;
    }
    return ret;
}
- (BOOL)setReferenceCountOfFileAtPath:(NSString *)thePath error:(NSError **)error {
    FlockFile *ff = [[[FlockFile alloc] initWithPath:lockFilePath] autorelease];
    __block BOOL ret = NO;
    if (![ff lockAndExecute:^void() { ret = [self lockedSetReferenceCountOfFileAtPath:thePath error:error]; } error:error]) {
        ret = NO;
    }
    return ret;
}
- (NSNumber *)totalSizeOfReferencedFilesInDirectory:(NSString *)theDir error:(NSError **)error {
    FlockFile *ff = [[[FlockFile alloc] initWithPath:lockFilePath] autorelease];
    __block NSNumber *ret = nil;
    if (![ff lockAndExecute:^void() { ret = [self lockedTotalSizeOfReferencedFilesInDirectory:theDir error:error]; } error:error]) {
        ret = nil;
    }
    return ret;
}
- (NSArray *)pathsOfUnreferencedFilesInDirectory:(NSString *)theDir error:(NSError **)error {
    FlockFile *ff = [[[FlockFile alloc] initWithPath:lockFilePath] autorelease];
    __block NSArray *ret = nil;
    if (![ff lockAndExecute:^void() { ret = [self lockedPathsOfUnreferencedFilesInDirectory:theDir error:error]; } error:error]) {
        ret = nil;
    }
    return ret;
}


#pragma mark internal
- (BOOL)lockedSetReferenceCountOfFileAtPath:(NSString *)thePath error:(NSError **)error {
    __block BOOL ret = NO;
    
    [fmdbq inDatabase:^(FMDatabase *db) {
        if (![db executeUpdate:@"UPDATE items SET refcount = 1 WHERE path = ?" withArgumentsInArray:[NSArray arrayWithObject:thePath]]) {
            SETNSERROR([ItemsDB errorDomain], [db lastErrorCode], @"db update refcount: error=%@, db=%@", [db lastErrorMessage], dbPath);
            return;
        }
//        if ([db changes] != 0) {
//            HSLogDebug(@"set refcount for %@", thePath);
//        }
        ret = YES;
    }];
    return ret;
}
- (NSNumber *)lockedTotalSizeOfReferencedFilesInDirectory:(NSString *)theDir error:(NSError **)error {
    __block NSNumber *ret = nil;
    
    theDir = [theDir slashed];
    [fmdbq inDatabase:^(FMDatabase *db) {
        NSString *theLikeParam = [theDir stringByAppendingString:@"%"];
        FMResultSet *rs = [db executeQuery:@"SELECT SUM(file_size) FROM items WHERE refcount > 0 AND slashed_directory LIKE ?" withArgumentsInArray:[NSArray arrayWithObject:theLikeParam]];
        if (rs == nil) {
            SETNSERROR([ItemsDB errorDomain], [db lastErrorCode], @"db select sum(file_size): error=%@, db=%@", [db lastErrorMessage], dbPath);
            return;
        }
        [rs next];
        unsigned long long total = [rs unsignedLongLongIntForColumnIndex:0];
        ret = [NSNumber numberWithUnsignedLongLong:total];
        [rs close];
    }];
    
    return ret;
}
- (NSArray *)lockedPathsOfUnreferencedFilesInDirectory:(NSString *)theDir error:(NSError **)error {
    __block NSMutableArray *ret = nil;
    
    theDir = [theDir slashed];
    [fmdbq inDatabase:^(FMDatabase *db) {
        NSString *theLikeParam = [theDir stringByAppendingString:@"%"];
        FMResultSet *rs = [db executeQuery:@"SELECT path FROM items WHERE refcount = 0 AND is_directory = 0 AND slashed_directory LIKE ?" withArgumentsInArray:[NSArray arrayWithObject:theLikeParam]];
        if (rs == nil) {
            SETNSERROR([ItemsDB errorDomain], [db lastErrorCode], @"db select unreferenced paths: error=%@, db=%@", [db lastErrorMessage], dbPath);
            return;
        }
        ret = [NSMutableArray array];
        while ([rs next]) {
            [ret addObject:[rs stringForColumnIndex:0]];
        }
        [rs close];
    }];
    
    return ret;
}
- (Item *)lockedItemAtPath:(NSString *)thePath error:(NSError **)error {
    NSString *theDirectory = [thePath stringByDeletingLastPathComponent];
    
    __block Item *ret = nil;
    
    [fmdbq inDatabase:^(FMDatabase *db) {
        NSNumber *loaded = [self isLoadedForDirectory:theDirectory db:db error:error];
        if (loaded == nil) {
            return;
        }
        if (![loaded boolValue]) {
            SETNSERROR([ItemsDB errorDomain], ERROR_CACHE_NOT_LOADED, @"itemAtPath: cache not loaded for directory %@", theDirectory);
            return;
        }
        
//        HSLogDebug(@"querying for item at path %@", thePath);
//        NSTimeInterval theTime = [NSDate timeIntervalSinceReferenceDate];
        FMResultSet *rs = [db executeQuery:@"SELECT name, item_id, parent_id, is_directory, file_size, file_last_modified, storage_class, checksum FROM items WHERE path = ?" withArgumentsInArray:[NSArray arrayWithObject:thePath]];
//        HSLogDebug(@"query for item at path %@ took %0.2f seconds", thePath, ([NSDate timeIntervalSinceReferenceDate] - theTime));
        if (rs == nil) {
            SETNSERROR([ItemsDB errorDomain], [db lastErrorCode], @"db select item at path: error=%@, db=%@", [db lastErrorMessage], dbPath);
            return;
        }
        if (![rs next]) {
            SETNSERROR([ItemsDB errorDomain], ERROR_NOT_FOUND, @"%@ not found", thePath);
            HSLogDebug(@"%@ not found in cached list of items", thePath);
        } else {
            ret = [[[Item alloc] init] autorelease];
            ret.name = [rs stringForColumnIndex:0];
            ret.itemId = [rs stringForColumnIndex:1];
            ret.parentId = [rs stringForColumnIndex:2];
            ret.isDirectory = [rs boolForColumnIndex:3];
            ret.fileSize = [rs intForColumnIndex:4];
            ret.fileLastModified = [rs dateForColumnIndex:5];
            ret.storageClass = [rs stringForColumnIndex:6];
            ret.checksum = [rs stringForColumnIndex:7];
        }
        [rs close];
    }];
    
    return ret;
}
- (NSMutableDictionary *)lockedItemsByNameInDirectory:(NSString *)theDirectory error:(NSError **)error {
    __block NSMutableDictionary *ret = nil;
    
    [fmdbq inDatabase:^(FMDatabase *db) {
        NSNumber *loaded = [self isLoadedForDirectory:theDirectory db:db error:error];
        if (loaded == nil) {
            return;
        }
        if (![loaded boolValue]) {
            SETNSERROR([ItemsDB errorDomain], ERROR_CACHE_NOT_LOADED, @"itemsByNameInDirectory: cache not loaded for directory %@", theDirectory);
            return;
        }
        
        NSString *slashedDirectory = [theDirectory stringByAppendingTrailingSlash];
        
//        HSLogDebug(@"query for items in directory %@", theDirectory);
//        NSTimeInterval theTime = [NSDate timeIntervalSinceReferenceDate];
        FMResultSet *rs = [db executeQuery:@"SELECT name, item_id, parent_id, is_directory, file_size, file_last_modified, storage_class, checksum FROM items WHERE slashed_directory = ?" withArgumentsInArray:[NSArray arrayWithObject:slashedDirectory]];
//        HSLogDebug(@"query for items in directory %@ took %0.2f seconds", theDirectory, ([NSDate timeIntervalSinceReferenceDate] - theTime));
        if (rs == nil) {
            SETNSERROR([ItemsDB errorDomain], [db lastErrorCode], @"db select items: error=%@, db=%@", [db lastErrorMessage], dbPath);
            return;
        }
        ret = [NSMutableDictionary dictionary];
        while ([rs next]) {
            Item *item = [[[Item alloc] init] autorelease];
            item.name = [rs stringForColumnIndex:0];
            item.itemId = [rs stringForColumnIndex:1];
            item.parentId = [rs stringForColumnIndex:2];
            item.isDirectory = [rs boolForColumnIndex:3];
            item.fileSize = [rs intForColumnIndex:4];
            item.fileLastModified = [rs dateForColumnIndex:5];
            item.storageClass = [rs stringForColumnIndex:6];
            item.checksum = [rs stringForColumnIndex:7];
            
            [ret setObject:item forKey:item.name];
        }
        [rs close];
    }];
    
    return ret;
}
- (BOOL)lockedSetItemsByName:(NSDictionary *)theItemsByName inDirectory:(NSString *)theDirectory error:(NSError **)error {
    __block BOOL ret = NO;
    
    [fmdbq inDatabase:^(FMDatabase *db) {
        if (![db beginTransaction]) {
            SETNSERROR([ItemsDB errorDomain], [db lastErrorCode], @"begin transaction in setItemsByName failed: error=%@, db=%@", [db lastErrorMessage], dbPath);
            return;
        }
        ret = [self doSetItemsByName:theItemsByName inDirectory:theDirectory database:db error:error];
        if (ret) {
            if (![db commit]) {
                SETNSERROR([ItemsDB errorDomain], [db lastErrorCode], @"commit in setItemsByName failed: error=%@, db=%@", [db lastErrorMessage], dbPath);
                ret = NO;
                return;
            }
        } else {
            [db rollback];
        }
    }];
    
    return ret;
}
- (BOOL)doSetItemsByName:(NSDictionary *)theItemsByName inDirectory:(NSString *)theDirectory database:(FMDatabase *)db error:(NSError **)error {
    NSString *slashedDirectory = [theDirectory stringByAppendingTrailingSlash];
    
    NSNumber *loaded = [self isLoadedForDirectory:theDirectory db:db error:error];
    if (loaded == nil) {
        return NO;
    }
    if (![loaded boolValue]) {
        if (![db executeUpdate:@"INSERT INTO loaded_directories (path) VALUES (?)" withArgumentsInArray:[NSArray arrayWithObject:theDirectory]]) {
            SETNSERROR([ItemsDB errorDomain], [db lastErrorCode], @"insert into loaded_directories: error=%@, db=%@", [db lastErrorMessage], dbPath);
            return NO;
        }
    }
    if (![db executeUpdate:@"DELETE FROM items WHERE slashed_directory = ?" withArgumentsInArray:[NSArray arrayWithObject:slashedDirectory]]) {
        SETNSERROR([ItemsDB errorDomain], [db lastErrorCode], @"delete items: error=%@, db=%@", [db lastErrorMessage], dbPath);
        return NO;
    }
    HSLogDebug(@"inserting %ld rows into the cache db for %@", [theItemsByName count], theDirectory);
    for (Item *item in [theItemsByName allValues]) {
        if (![self deleteAndInsertItem:item inDirectory:slashedDirectory db:db error:error]) {
            return NO;
        }
    }
    HSLogDebug(@"inserted %ld rows into the cache db for %@", [theItemsByName count], theDirectory);
    
    return YES;
}
- (BOOL)lockedClearItemsByNameInDirectory:(NSString *)theDirectory error:(NSError **)error {
    HSLogDebug(@"deleting cached data for %@ and all subdirectories", theDirectory);
    
    NSString *slashedDirectory = [theDirectory stringByAppendingTrailingSlash];
    
    __block BOOL ret = NO;
    
    [fmdbq inDatabase:^(FMDatabase *db) {
        // Delete loaded_directories.
        NSArray *args = [NSArray arrayWithObjects:theDirectory, [slashedDirectory stringByAppendingString:@"%"], nil];
        if (![db executeUpdate:@"DELETE FROM loaded_directories WHERE path = ? OR path LIKE ?" withArgumentsInArray:args]) {
            SETNSERROR([ItemsDB errorDomain], [db lastErrorCode], @"delete from loaded_directories for %@: error=%@, db=%@", theDirectory, [db lastErrorMessage], dbPath);
            return;
        }
        
        // Delete items.
        if (![db executeUpdate:@"DELETE FROM items WHERE slashed_directory LIKE ?" withArgumentsInArray:[NSArray arrayWithObject:[slashedDirectory stringByAppendingString:@"%"]]]) {
            SETNSERROR([ItemsDB errorDomain], [db lastErrorCode], @"delete from items for %@: error=%@, db=%@", theDirectory, [db lastErrorMessage], dbPath);
            return;
        }
        
        ret = YES;
    }];
    
    return ret;
}
- (BOOL)lockedDestroy:(NSError **)error {
    if ([[NSFileManager defaultManager] fileExistsAtPath:dbPath]) {
        if (![[NSFileManager defaultManager] removeItemAtPath:dbPath error:error]) {
            return NO;
        }
    }
    return YES;
}
- (BOOL)lockedAddItem:(Item *)theItem inDirectory:(NSString *)theDirectory error:(NSError **)error {
    __block BOOL ret = NO;
    
    [fmdbq inDatabase:^(FMDatabase *db) {
        NSNumber *loaded = [self isLoadedForDirectory:theDirectory db:db error:error];
        if (loaded == nil) {
            return;
        }
        if (![loaded boolValue]) {
            SETNSERROR([ItemsDB errorDomain], ERROR_CACHE_NOT_LOADED, @"addItem: cache not loaded for directory %@", theDirectory);
            return;
        }
        
        if (![db beginTransaction]) {
            SETNSERROR([ItemsDB errorDomain], [db lastErrorCode], @"begin transaction in addItem failed: error=%@, db=%@", [db lastErrorMessage], dbPath);
            return;
        }
        ret = [self insertItem:theItem inDirectory:theDirectory db:db error:error];
        if (ret) {
            if (![db commit]) {
                SETNSERROR([ItemsDB errorDomain], [db lastErrorCode], @"commit in addItem failed: error=%@, db=%@", [db lastErrorMessage], dbPath);
                ret = NO;
                return;
            }
        } else {
            [db rollback];
        }
    }];
    
    return ret;
}
- (BOOL)lockedAddOrReplaceItem:(Item *)theItem inDirectory:(NSString *)theDirectory error:(NSError **)error {
    __block BOOL ret = NO;
    
    [fmdbq inDatabase:^(FMDatabase *db) {
        NSNumber *loaded = [self isLoadedForDirectory:theDirectory db:db error:error];
        if (loaded == nil) {
            return;
        }
        if (![loaded boolValue]) {
            SETNSERROR([ItemsDB errorDomain], ERROR_CACHE_NOT_LOADED, @"addOrReplaceItem: cache not loaded for directory %@", theDirectory);
            return;
        }
        
        if (![db beginTransaction]) {
            SETNSERROR([ItemsDB errorDomain], [db lastErrorCode], @"begin transaction in addOrReplaceItem failed: error=%@, db=%@", [db lastErrorMessage], dbPath);
            return;
        }
        ret = [self deleteAndInsertItem:theItem inDirectory:theDirectory db:db error:error];
        if (ret) {
            if (![db commit]) {
                SETNSERROR([ItemsDB errorDomain], [db lastErrorCode], @"commit in addOrReplaceItem failed: error=%@, db=%@", [db lastErrorMessage], dbPath);
                ret = NO;
                return;
            }
        } else {
            [db rollback];
        }
    }];
    
    return ret;
}
- (BOOL)lockedRemoveItemWithName:(NSString *)theItemName inDirectory:(NSString *)theDirectory error:(NSError **)error {
    __block BOOL ret = NO;
    
    [fmdbq inDatabase:^(FMDatabase *db) {
        NSNumber *loaded = [self isLoadedForDirectory:theDirectory db:db error:error];
        if (loaded == nil) {
            return;
        }
        if (![loaded boolValue]) {
            SETNSERROR([ItemsDB errorDomain], ERROR_CACHE_NOT_LOADED, @"removeItemWithName: cache not loaded for directory %@", theDirectory);
            return;
        }
        
        NSString *slashedDirectory = [theDirectory stringByAppendingTrailingSlash];
        if (![db executeUpdate:@"DELETE FROM items WHERE name = ? AND slashed_directory = ?" withArgumentsInArray:[NSArray arrayWithObjects:theItemName, slashedDirectory, nil]]) {
            SETNSERROR([ItemsDB errorDomain], [db lastErrorCode], @"delete from items for %@ in %@: error=%@, db=%@", theItemName, theDirectory, [db lastErrorMessage], dbPath);
            return;
        }
        
        ret = YES;
    }];
    
    return ret;
}
- (BOOL)lockedMoveItem:(Item *)theItem fromDirectory:(NSString *)theFromDirectory toDirectory:(NSString *)theToDirectory error:(NSError **)error {
    __block BOOL ret = NO;
    
    [fmdbq inDatabase:^(FMDatabase *db) {
        if (![db beginTransaction]) {
            SETNSERROR([ItemsDB errorDomain], [db lastErrorCode], @"begin transaction in setItemsByName failed: error=%@, db=%@", [db lastErrorMessage], dbPath);
            return;
        }
        ret = [self doLockedMoveItem:theItem fromDirectory:theFromDirectory toDirectory:theToDirectory error:error];
        if (ret) {
            if (![db commit]) {
                SETNSERROR([ItemsDB errorDomain], [db lastErrorCode], @"commit in setItemsByName failed: error=%@, db=%@", [db lastErrorMessage], dbPath);
                ret = NO;
                return;
            }
        } else {
            [db rollback];
        }
    }];
    return ret;
}
- (BOOL)doLockedMoveItem:(Item *)theItem fromDirectory:(NSString *)theFromDirectory toDirectory:(NSString *)theToDirectory error:(NSError **)error {
    __block BOOL ret = NO;
    
    [fmdbq inDatabase:^(FMDatabase *db) {
        NSNumber *loaded = [self isLoadedForDirectory:theFromDirectory db:db error:error];
        if (loaded == nil) {
            return;
        }
        if (![loaded boolValue]) {
            SETNSERROR([ItemsDB errorDomain], ERROR_CACHE_NOT_LOADED, @"removeItemWithName: cache not loaded for directory %@", theFromDirectory);
            return;
        }
        loaded = [self isLoadedForDirectory:theToDirectory db:db error:error];
        if (loaded == nil) {
            return;
        }
        if (![loaded boolValue]) {
            SETNSERROR([ItemsDB errorDomain], ERROR_CACHE_NOT_LOADED, @"removeItemWithName: cache not loaded for directory %@", theToDirectory);
            return;
        }
        
        NSString *slashedFromDirectory = [theFromDirectory stringByAppendingTrailingSlash];
        if (![db executeUpdate:@"DELETE FROM items WHERE name = ? AND slashed_directory = ?" withArgumentsInArray:[NSArray arrayWithObjects:theItem.name, slashedFromDirectory, nil]]) {
            SETNSERROR([ItemsDB errorDomain], [db lastErrorCode], @"delete from items for %@ in %@: error=%@, db=%@", theItem.name, theFromDirectory, [db lastErrorMessage], dbPath);
            return;
        }
        
        if (![self insertItem:theItem inDirectory:theToDirectory db:db error:error]) {
            return;
        }
        ret = YES;
    }];
    
    return ret;
}
- (BOOL)lockedClearReferenceCounts:(NSError **)error {
    __block BOOL ret = NO;
    
    [fmdbq inDatabase:^(FMDatabase *db) {
        if (![db executeUpdate:@"UPDATE items SET refcount = 0"]) {
            SETNSERROR([ItemsDB errorDomain], [db lastErrorCode], @"update refcount to 0 error: %@, db=%@", [db lastErrorMessage], dbPath);
            return;
        }
        int rowsChanged = [db changes];
        HSLogDebug(@"set refcount to 0 on %d rows", rowsChanged);
        ret = YES;
    }];
    
    return ret;
}
- (BOOL)insertItem:(Item *)theItem inDirectory:(NSString *)theDirectory db:(FMDatabase *)db error:(NSError **)error {
    NSAssert([db inTransaction], @"must be in a transaction");
    
    NSString *thePath = [theDirectory stringByAppendingPathComponent:theItem.name];
    FMResultSet *rs = [db executeQuery:@"SELECT name, item_id, parent_id, is_directory, file_size, file_last_modified, storage_class, checksum FROM items WHERE path = ?" withArgumentsInArray:[NSArray arrayWithObject:thePath]];
    if (rs == nil) {
        SETNSERROR([ItemsDB errorDomain], [db lastErrorCode], @"db select item at path: error=%@, db=%@", [db lastErrorMessage], dbPath);
        return NO;
    }
    Item *existing = nil;
    if ([rs next]) {
        existing = [[[Item alloc] init] autorelease];
        existing.name = [rs stringForColumnIndex:0];
        existing.itemId = [rs stringForColumnIndex:1];
        existing.parentId = [rs stringForColumnIndex:2];
        existing.isDirectory = [rs boolForColumnIndex:3];
        existing.fileSize = [rs intForColumnIndex:4];
        existing.fileLastModified = [rs dateForColumnIndex:5];
        existing.storageClass = [rs stringForColumnIndex:6];
        existing.checksum = [rs stringForColumnIndex:7];
    }
    [rs close];
    if (existing != nil) {
        NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                                  @"item exists", NSLocalizedDescriptionKey,
                                  existing, @"previouslyExistingItem", nil];
        NSError *myError = [[[NSError alloc] initWithDomain:[ItemsDB errorDomain] code:ERROR_ITEM_EXISTS userInfo:userInfo] autorelease];
        HSLogDebug(@"insertItem: %@", myError);
        SETERRORFROMMYERROR;
        return NO;
    }

    /* columns:
     path
     slashed_directory
     name
     item_id
     parent_id
     is_directory
     file_size
     file_last_modified
     storage_class
     checksum
     */
    NSArray *args = [NSArray arrayWithObjects:thePath,
                     [theDirectory stringByAppendingTrailingSlash],
                     theItem.name,
                     (theItem.itemId != nil ? theItem.itemId : [NSNull null]),
                     (theItem.parentId != nil ? theItem.parentId : [NSNull null]),
                     [NSNumber numberWithInt:(theItem.isDirectory ? 1 : 0)],
                     [NSNumber numberWithUnsignedLongLong:theItem.fileSize],
                     (theItem.fileLastModified != nil ? [NSNumber numberWithDouble:[theItem.fileLastModified timeIntervalSince1970]] : [NSNull null]),
                     (theItem.storageClass != nil ? theItem.storageClass : [NSNull null]),
                     (theItem.checksum != nil ? theItem.checksum : [NSNull null]),
                     nil];
    if (![db executeUpdate:@"INSERT INTO items (path, slashed_directory, name, item_id, parent_id, is_directory, file_size, file_last_modified, storage_class, checksum) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)" withArgumentsInArray:args]) {
        return NO;
    }
    return YES;
}
- (BOOL)deleteAndInsertItem:(Item *)theItem inDirectory:(NSString *)theDirectory db:(FMDatabase *)db error:(NSError **)error {
    NSAssert([db inTransaction], @"must be in a transaction");
    
    NSString *thePath = [theDirectory stringByAppendingPathComponent:theItem.name];
    if (![db executeUpdate:@"DELETE FROM items WHERE path = ?" withArgumentsInArray:[NSArray arrayWithObjects:thePath, nil]]) {
        SETNSERROR([ItemsDB errorDomain], [db lastErrorCode], @"delete error: error=%@, db=%@", [db lastErrorMessage], dbPath);
        return NO;
    }
    
    /* columns:
     path
     slashed_directory
     name
     item_id
     parent_id
     is_directory
     file_size
     file_last_modified
     storage_class
     checksum
     */
    NSArray *args = [NSArray arrayWithObjects:thePath,
                     [theDirectory stringByAppendingTrailingSlash],
                     theItem.name,
                     (theItem.itemId != nil ? theItem.itemId : [NSNull null]),
                     (theItem.parentId != nil ? theItem.parentId : [NSNull null]),
                     [NSNumber numberWithInt:(theItem.isDirectory ? 1 : 0)],
                     [NSNumber numberWithUnsignedLongLong:theItem.fileSize],
                     (theItem.fileLastModified != nil ? [NSNumber numberWithDouble:[theItem.fileLastModified timeIntervalSince1970]] : [NSNull null]),
                     (theItem.storageClass != nil ? theItem.storageClass : [NSNull null]),
                     (theItem.checksum != nil ? theItem.checksum : [NSNull null]),
                     nil];
    if (![db executeUpdate:@"INSERT INTO items (path, slashed_directory, name, item_id, parent_id, is_directory, file_size, file_last_modified, storage_class, checksum) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)" withArgumentsInArray:args]) {
        return NO;
    }
    return YES;
}
- (NSNumber *)isLoadedForDirectory:(NSString *)theDirectory db:(FMDatabase *)db error:(NSError **)error {
    NSNumber *ret = nil;
    
//    HSLogDebug(@"query for count of loaded_directories for %@", theDirectory);
//    NSTimeInterval theTime = [NSDate timeIntervalSinceReferenceDate];
    FMResultSet *rs = [db executeQuery:@"SELECT COUNT(*) AS COUNT FROM loaded_directories WHERE path = ?" withArgumentsInArray:[NSArray arrayWithObject:theDirectory]];
//    HSLogDebug(@"query for count of loaded_directories for %@ took %0.2f seconds", theDirectory, ([NSDate timeIntervalSinceReferenceDate] - theTime));
    if (rs == nil) {
        SETNSERROR([ItemsDB errorDomain], [db lastErrorCode], @"db select items: error=%@, db=%@", [db lastErrorMessage], dbPath);
        return nil;
    }
    if (![rs next]) {
        SETNSERROR([ItemsDB errorDomain], -1, @"db select: no row!");
    } else {
        int count = [rs intForColumnIndex:0];
        ret = [NSNumber numberWithBool:(count > 0)];
    }
    [rs close];
    
    return ret;
}

- (FMDatabaseQueue *)initDB:(NSError **)error {
    if (![[NSFileManager defaultManager] ensureParentPathExistsForPath:dbPath targetUID:[[CacheOwnership sharedCacheOwnership] uid] targetGID:[[CacheOwnership sharedCacheOwnership] gid] error:error]) {
        return nil;
    }
    
    __block BOOL ret = NO;
    
    FMDatabaseQueue *dbq = [FMDatabaseQueue databaseQueueWithPath:dbPath];
    [dbq inDatabase:^(FMDatabase *db) {
        if (chmod([dbPath fileSystemRepresentation], S_IRUSR|S_IWUSR|S_IRGRP|S_IWGRP|S_IROTH|S_IWOTH) < 0) {
            int errnum = errno;
            HSLogError(@"chmod(%@) error %d: %s", dbPath, errnum, strerror(errnum));
        }
        if (chown([dbPath fileSystemRepresentation], [[CacheOwnership sharedCacheOwnership] uid], [[CacheOwnership sharedCacheOwnership] gid]) == -1) {
            int errnum = errno;
            SETNSERROR(@"UnixErrorDomain", errnum, @"chown(%@, %d, %d): %s", dbPath, [[CacheOwnership sharedCacheOwnership] uid], [[CacheOwnership sharedCacheOwnership] gid], strerror(errnum));
            return;
        }
        if (![db executeUpdate:@"CREATE TABLE IF NOT EXISTS loaded_directories (path TEXT NOT NULL PRIMARY KEY)"]) {
            SETNSERROR([ItemsDB errorDomain], [db lastErrorCode], @"db create table: error=%@, db=%@", [db lastErrorMessage], dbPath);
            return;
        }
        if (![db executeUpdate:@"CREATE TABLE IF NOT EXISTS items (path TEXT NOT NULL PRIMARY KEY, slashed_directory TEXT NOT NULL, name TEXT NOT NULL, item_id TEXT, parent_id TEXT, is_directory INT, file_size INTEGER, file_last_modified REAL, storage_class TEXT, checksum TEXT)"]) {
            SETNSERROR([ItemsDB errorDomain], [db lastErrorCode], @"db create table: error=%@, db=%@", [db lastErrorMessage], dbPath);
            return;
        }
        [db setShouldCacheStatements:YES];
        
        if (![db columnExists:@"checksum" inTableWithName:@"items"]) {
            // Update database schema and delete the data.
            if (![db executeUpdate:@"ALTER TABLE items ADD COLUMN checksum TEXT"]) {
                SETNSERROR([ItemsDB errorDomain], [db lastErrorCode], @"db alter table: error=%@, db=%@", [db lastErrorMessage], dbPath);
                return;
            }
            if (![db beginTransaction]) {
                SETNSERROR([ItemsDB errorDomain], [db lastErrorCode], @"db begin transaction: error=%@, db=%@", [db lastErrorMessage], dbPath);
                return;
            }
            BOOL ret = [db executeUpdate:@"DELETE FROM items"]
            && [db executeUpdate:@"DELETE FROM loaded_directories"];
            if (ret) {
                [db commit];
            } else {
                SETNSERROR([ItemsDB errorDomain], [db lastErrorCode], @"db delete: error=%@, db=%@", [db lastErrorMessage], dbPath);
                [db rollback];
                return;
            }
        }
        
        if (![db columnExists:@"refcount" inTableWithName:@"items"]) {
            if (![db executeUpdate:@"ALTER TABLE items ADD COLUMN refcount INTEGER NOT NULL DEFAULT 0"]) {
                SETNSERROR([ItemsDB errorDomain], [db lastErrorCode], @"db alter table: error=%@, db=%@", [db lastErrorMessage], dbPath);
                return;
            }
        }
        
        if ([self schemaVersion] == 0) {
            if (![db executeUpdate:@"CREATE INDEX items_slashed_directory ON items (slashed_directory)"]) {
                NSString *msg = [db lastErrorMessage];
                if ([msg rangeOfString:@"already exists"].location != NSNotFound) {
                    SETNSERROR([ItemsDB errorDomain], [db lastErrorCode], @"db create index items_slashed_directory: error=%@, db=%@", [db lastErrorMessage], dbPath);
                    return;
                } else {
                    HSLogDebug(@"db create index items_slashed_directory: %@", msg);
                }
            }
            if (![self setSchemaVersion:1 error:error]) {
                return;
            }
        }
        if ([self schemaVersion] == 1) {
            if (![db executeUpdate:@"CREATE INDEX items_is_directory ON items (is_directory)"]) {
                SETNSERROR([ItemsDB errorDomain], [db lastErrorCode], @"db create index items_is_directory: error=%@, db=%@", [db lastErrorMessage], dbPath);
                return;
            }
            if (![self setSchemaVersion:2 error:error]) {
                return;
            }
        }
        if ([self schemaVersion] == 2) {
            if (![db executeUpdate:@"CREATE INDEX items_refcount ON items (refcount)"]) {
                SETNSERROR([ItemsDB errorDomain], [db lastErrorCode], @"db create index items_refcount: error=%@, db=%@", [db lastErrorMessage], dbPath);
                return;
            }
            if (![self setSchemaVersion:3 error:error]) {
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
        if (![db tableExists:@"items_schema"]) {
            if (![db executeUpdate:@"CREATE TABLE IF NOT EXISTS items_schema (version INTEGER NOT NULL PRIMARY KEY)"]) {
                HSLogError(@"db create table: error=%@, db=%@", [db lastErrorMessage], dbPath);
                return;
            }
        }
        
        FMResultSet *rs = [db executeQuery:@"SELECT version FROM items_schema" withArgumentsInArray:[NSArray array]];
        if (rs == nil) {
            HSLogError(@"db select version: error=%@, db=%@", [db lastErrorMessage], dbPath);
            return;
        }
        if (![rs next]) {
            if (![db executeUpdate:@"INSERT INTO items_schema VALUES (0)"]) {
                HSLogError(@"db insert into items_schema: error=%@, db=%@", [db lastErrorMessage], dbPath);
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
    HSLogDebug(@"updating items schema version from %d to %d", currentVersion, theSchemaVersion);
    
    __block BOOL ret = NO;
    FMDatabaseQueue *dbq = [FMDatabaseQueue databaseQueueWithPath:dbPath];
    [dbq inDatabase:^(FMDatabase *db) {
        if (![db executeUpdate:@"UPDATE items_schema SET version = ?" withArgumentsInArray:[NSArray arrayWithObject:[NSNumber numberWithInt:theSchemaVersion]]]) {
            SETNSERROR([ItemsDB errorDomain], [db lastErrorCode], @"db update items_schema: error=%@, db=%@", [db lastErrorMessage], dbPath);
            return;
        }
        ret = YES;
    }];
    
    return ret;
}
@end
