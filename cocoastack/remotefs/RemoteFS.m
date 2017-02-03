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



#import "RemoteFS.h"
#import "Target.h"
#import "Item.h"
#import "UserLibrary_Arq.h"
#import "NSString_extra.h"
#import "FlockFile.h"
#import "ItemsDB.h"
#import "RemoteFSFileDeleter.h"
#import "ItemFSFileDeleter.h"


@implementation RemoteFS
- (id)initWithItemFS:(id <ItemFS>)theItemFS cacheUUID:(NSString *)theCacheUUID {
    if (self = [super init]) {
        itemFS = [theItemFS retain];
        cacheUUID = [theCacheUUID retain];
        lockFilePath = [[[[UserLibrary arqCachePath] stringByAppendingPathComponent:theCacheUUID] stringByAppendingPathComponent:@"remotefs.lock"] retain];
    }
    return self;
}
- (void)dealloc {
    [lockFilePath release];
    [itemFS release];
    [cacheUUID release];
    [super dealloc];
}


- (NSString *)remoteFSErrorDomain {
    return @"RemoteFSErrorDomain";
}
- (BOOL)updateFingerprintWithTargetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD error:(NSError **)error {
    return [itemFS updateFingerprintWithTargetConnectionDelegate:theTCD error:error];
}
- (Item *)itemAtPath:(NSString *)thePath targetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD error:(NSError **)error {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    Item *ret = [self doItemAtPath:thePath targetConnectionDelegate:theTCD error:error];
    
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
- (NSDictionary *)itemsByNameInDirectory:(NSString *)thePath targetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD error:(NSError **)error {
    return [self itemsByNameInDirectory:thePath useCachedData:YES targetConnectionDelegate:theTCD error:error];
}
- (NSDictionary *)itemsByNameInDirectory:(NSString *)thePath useCachedData:(BOOL)theUseCachedData targetConnectionDelegate:(id<TargetConnectionDelegate>)theTCD error:(NSError **)error {
    FlockFile *ff = [[[FlockFile alloc] initWithPath:lockFilePath] autorelease];
    __block NSDictionary *ret = nil;
    if (![ff lockAndExecute:^void() { ret = [self lockedItemsByNameInDirectory:thePath useCachedData:theUseCachedData targetConnectionDelegate:theTCD error:error]; } error:error]) {
        return nil;
    }
    return ret;
}
- (NSData *)contentsOfFileAtPath:(NSString *)thePath dataTransferDelegate:(id<DataTransferDelegate>)theDTDelegate targetConnectionDelegate:(id<TargetConnectionDelegate>)theTCDelegate error:(NSError **)error {
    return [self contentsOfRange:NSMakeRange(NSNotFound, 0) ofFileAtPath:thePath dataTransferDelegate:theDTDelegate targetConnectionDelegate:theTCDelegate error:error];
}
- (NSData *)contentsOfRange:(NSRange)theRange ofFileAtPath:(NSString *)thePath dataTransferDelegate:(id <DataTransferDelegate>)theDTD targetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD error:(NSError **)error {
    Item *item = nil;
    if ([itemFS usesFolderIds]) {
        // Only get the Item if we need it for its itemID:
        item = [self itemAtPath:thePath targetConnectionDelegate:theTCD error:error];
        if (item == nil) {
            return nil;
        }
    }
    if (theRange.location == NSNotFound) {
        HSLogDetail(@"getting contents of %@:%@", [itemFS itemFSDescription], thePath);
    } else {
        HSLogDetail(@"getting contents of range (%ld,%ld) of %@:%@", theRange.location, theRange.length, [itemFS itemFSDescription], thePath);
    }
    return [itemFS contentsOfRange:theRange ofFileItem:item itemPath:thePath dataTransferDelegate:theDTD targetConnectionDelegate:theTCD error:error];
}
- (Item *)createFileAtomicallyWithData:(NSData *)theData atPath:(NSString *)thePath dataTransferDelegate:(id <DataTransferDelegate>)theDTD targetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD error:(NSError **)error {
    NSString *directory = [thePath stringByDeletingLastPathComponent];
    NSError *myError = nil;
    Item *directoryItem = [self itemAtPath:directory targetConnectionDelegate:theTCD error:&myError];
    if (directoryItem == nil) {
        if ([myError code] != ERROR_NOT_FOUND) {
            SETERRORFROMMYERROR;
            return nil;
        }
        directoryItem = [self createDirectoryAtPath:directory targetConnectionDelegate:theTCD error:error];
        if (directoryItem == nil) {
            return nil;
        }
    }
    Item *theExistingItem = [self itemAtPath:thePath targetConnectionDelegate:theTCD error:&myError];
    if (theExistingItem == nil && [myError code] != ERROR_NOT_FOUND) {
        SETERRORFROMMYERROR;
        return nil;
    }
    HSLogDetail(@"creating file %@:%@", [itemFS itemFSDescription], thePath);
    __block Item *ret = [itemFS createFileWithData:theData name:[thePath lastPathComponent] inDirectoryItem:directoryItem existingItem:theExistingItem itemPath:thePath dataTransferDelegate:theDTD targetConnectionDelegate:theTCD error:error];
    if (ret == nil) {
        return nil;
    }
    
    //    if (![itemFS enforcesUniqueFilenames]) {
    //        // We may have created an additional file with the same name (only Google Drive returns false for enforcesUniqueFilenames).
    //        if (![self addItemToCache:item inDirectory:[thePath stringByDeletingLastPathComponent] error:&myError]) {
    //            if ([myError code] != ERROR_ITEM_EXISTS) {
    //                SETERRORFROMMYERROR;
    //                return nil;
    //            }
    //            Item *foundItem = [[myError userInfo] objectForKey:@"previouslyExistingItem"];
    //            NSAssert(foundItem != nil, @"foundItem may not be nil");
    //
    //            if (![itemFS removeItemById:foundItem.itemId targetConnectionDelegate:theTCD error:&myError]) {
    //                SETERRORFROMMYERROR;
    //                HSLogError(@"failed to delete the duplicate file %@ we just created: %@", thePath, myError);
    //                return nil;
    //            }
    //            item = foundItem;
    //        }
    //    } else {
    // We overwrote it, so overwrite the item in the cache too.
    
    FlockFile *ff = [[[FlockFile alloc] initWithPath:lockFilePath] autorelease];
    __block BOOL addOrReplaceSuccess = NO;
    if (![ff lockAndExecute:^void() { addOrReplaceSuccess = [self lockedAddOrReplaceItemInCache:ret inDirectory:[thePath stringByDeletingLastPathComponent] error:error]; } error:error]) {
        ret = nil;
    }
    if (!addOrReplaceSuccess) {
        ret = nil;
    }
    
    return ret;
}
- (BOOL)moveItemAtPath:(NSString *)thePath toPath:(NSString *)theDestinationPath targetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD error:(NSError **)error {
    __block BOOL ret = NO;
    FlockFile *ff = [[[FlockFile alloc] initWithPath:lockFilePath] autorelease];
    if (![ff lockAndExecute:^void() { ret = [self lockedMoveItemAtPath:thePath toPath:theDestinationPath targetConnectionDelegate:theTCD error:error]; } error:error]) {
        return NO;
    }
    return ret;
}
- (BOOL)lockedMoveItemAtPath:(NSString *)thePath toPath:(NSString *)theDestinationPath targetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD error:(NSError **)error {
    HSLogDetail(@"moving %@:%@ to %@", [itemFS itemFSDescription], thePath, theDestinationPath);
    Item *existing = [self lockedItemAtPath:thePath targetConnectionDelegate:theTCD error:error];
    if (existing == nil) {
        return NO;
    }
    NSString *fromDir = [thePath stringByDeletingLastPathComponent];
    NSString *toDir = [theDestinationPath stringByDeletingLastPathComponent];
    Item *fromDirItem = [self lockedItemAtPath:fromDir targetConnectionDelegate:theTCD error:error];
    if (fromDirItem == nil) {
        return NO;
    }
    NSError *myError = nil;
    Item *toDirItem = [self lockedItemAtPath:toDir targetConnectionDelegate:theTCD error:&myError];
    if (toDirItem == nil) {
        if ([myError code] != ERROR_NOT_FOUND) {
            SETERRORFROMMYERROR;
            return NO;
        }
        toDirItem = [self lockedCreateDirectoryAtPath:toDir targetConnectionDelegate:theTCD error:error];
        if (toDirItem == nil) {
            return NO;
        }
    }
    if (![itemFS moveItem:existing toNewName:[theDestinationPath lastPathComponent] fromDirectoryItem:fromDirItem fromDirectory:fromDir toDirectoryItem:toDirItem toDirectory:toDir targetConnectionDelegate:theTCD error:error]) {
        return NO;
    }
    existing.fileLastModified = [NSDate date];
    
    myError = nil;
    if (![self lockedMoveCachedItem:existing fromDirectory:fromDir toDirectory:toDir error:&myError]) {
        if ([myError code] != ERROR_CACHE_NOT_LOADED) {
            SETERRORFROMMYERROR;
            return NO;
        }
    }
    
    return YES;
}
- (BOOL)removeItemAtPath:(NSString *)thePath targetConnectionDelegate:(id<TargetConnectionDelegate>)theTCD error:(NSError **)error {
    HSLogInfo(@"deleting item %@:%@", [itemFS itemFSDescription], thePath);

    // This method might hold this lock a VERY long time, if it's deleting a huge directory and the ItemFS can't delete directories in one go.
    
    __block BOOL ret = NO;
    FlockFile *ff = [[[FlockFile alloc] initWithPath:lockFilePath] autorelease];
    if (![ff lockAndExecute:^void() { ret = [self lockedRemoveItemAtPath:thePath targetConnectionDelegate:theTCD error:error]; } error:error]) {
        return NO;
    }
    return ret;
}
- (Item *)createDirectoryAtPath:(NSString *)path targetConnectionDelegate:(id<TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    HSLogDetail(@"creating directory %@", path);
    
    __block Item *ret = nil;
    FlockFile *ff = [[[FlockFile alloc] initWithPath:lockFilePath] autorelease];
    if (![ff lockAndExecute:^void() { ret = [self lockedCreateDirectoryAtPath:path targetConnectionDelegate:theDelegate error:error]; } error:error]) {
        ret = nil;
    }
    return ret;
}
- (NSNumber *)isObjectRestoredAtPath:(NSString *)thePath targetConnectionDelegate:(id<TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    return [itemFS isObjectRestoredAtPath:thePath targetConnectionDelegate:theDelegate error:error];
}
- (BOOL)restoreObjectAtPath:(NSString *)thePath forDays:(NSUInteger)theDays tier:(int)theGlacierRetrievalTier alreadyRestoredOrRestoring:(BOOL *)alreadyRestoredOrRestoring targetConnectionDelegate:(id<TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    HSLogDetail(@"restoring %@", thePath);
    return [itemFS restoreObjectAtPath:thePath forDays:theDays tier:theGlacierRetrievalTier alreadyRestoredOrRestoring:alreadyRestoredOrRestoring targetConnectionDelegate:theDelegate error:error];
}
- (NSNumber *)freeBytesAtPath:(NSString *)thePath targetConnectionDelegate:(id<TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    return [itemFS freeBytesAtPath:thePath targetConnectionDelegate:theDelegate error:error];
}
- (BOOL)clearCacheForPath:(NSString *)thePath error:(NSError **)error {
    HSLogInfo(@"clearing cache for %@:%@", [itemFS itemFSDescription], thePath);
    __block BOOL ret = NO;
    FlockFile *ff = [[[FlockFile alloc] initWithPath:lockFilePath] autorelease];
    if (![ff lockAndExecute:^void() { ret = [self lockedClearCachedItemsForDirectory:thePath error:error]; } error:error]) {
        ret = NO;
    }
    return ret;
}
- (BOOL)clearCache:(NSError **)error {
    HSLogInfo(@"clearing cache for %@", [itemFS itemFSDescription]);
    __block BOOL ret = NO;
    FlockFile *ff = [[[FlockFile alloc] initWithPath:lockFilePath] autorelease];
    if (![ff lockAndExecute:^void() { ret = [self lockedClearAllCachedItems:error]; } error:error]) {
        ret = NO;
    }
    return ret;
}


#pragma mark internal
- (NSArray *)lockedPathsOfUnreferencedFilesInDirectories:(NSArray *)theDirectories error:(NSError **)error {
    NSMutableArray *allPaths = [NSMutableArray array];
    for (NSString *dir in theDirectories) {
        NSArray *paths = [[ItemsDB sharedItemsDB] pathsOfUnreferencedFilesInDirectory:dir targetUUID:cacheUUID error:error];
        if (paths == nil) {
            return nil;
        }
        [allPaths addObjectsFromArray:paths];
    }
    return allPaths;
}
- (Item *)doItemAtPath:(NSString *)thePath targetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD error:(NSError **)error {
    __block Item *ret = nil;
    FlockFile *ff = [[[FlockFile alloc] initWithPath:lockFilePath] autorelease];
    if (![ff lockAndExecute:^void() { ret = [self lockedItemAtPath:thePath targetConnectionDelegate:theTCD error:error]; } error:error]) {
        return nil;
    }
    return ret;
}
- (Item *)lockedItemAtPath:(NSString *)thePath targetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD error:(NSError **)error {
    Item *ret = nil;
    if ([thePath isEqualToString:@"/"]) {
        HSLogDebug(@"returning root item");
        ret = [itemFS rootDirectoryItemWithTargetConnectionDelegate:theTCD error:error];
    } else {
        NSError *myError = nil;
        ret = [self lockedCachedItemAtPath:thePath error:&myError];
        if (ret != nil && [itemFS usesFolderIds] && [ret itemId] == nil) {
            NSError *cacheError = nil;
            NSString *parentPath = [thePath stringByDeletingLastPathComponent];
            if (![self lockedClearCachedItemsForDirectory:parentPath error:&cacheError]) {
                HSLogError(@"failed to clear cache for %@: %@", parentPath, cacheError);
            }
            ret = [self lockedCachedItemAtPath:thePath error:&myError];
        }
        if (ret == nil) {
            if ([myError code] == ERROR_CACHE_NOT_LOADED) {
                HSLogDebug(@"cache not loaded; getting items for parent dir of %@", thePath);
                NSString *parentDir = [thePath stringByDeletingLastPathComponent];
                NSString *fileName = [thePath lastPathComponent];
                NSDictionary *itemsByName = [self lockedItemsByNameInDirectory:parentDir useCachedData:YES targetConnectionDelegate:theTCD error:error];
                if (itemsByName == nil) {
                    return nil;
                }
                ret = [itemsByName objectForKey:fileName];
                if (ret == nil) {
                    HSLogDebug(@"didn't find %@ in parent dir %@", fileName, parentDir);
                    SETNSERROR([self remoteFSErrorDomain], ERROR_NOT_FOUND, @"%@ not found", thePath);
                } else {
                    HSLogDebug(@"found actual item at %@", thePath);
                }
            } else {
                SETERRORFROMMYERROR;
            }
            //        } else {
            //            HSLogDebug(@"found cached item at %@", thePath);
        }
    }
    return ret;
}
- (NSDictionary *)lockedItemsByNameInDirectory:(NSString *)thePath useCachedData:(BOOL)theUseCachedData targetConnectionDelegate:(id<TargetConnectionDelegate>)theTCD error:(NSError **)error {
    NSError *myError = nil;
    NSDictionary *ret = nil;
    if (theUseCachedData) {
        ret = [self lockedCachedItemsByNameForDirectory:thePath error:&myError];
        if (ret == nil) {
            HSLogDebug(@"cachedItemsByNameForDirectory returned nil; error=%@", myError);
            if ([myError code] != ERROR_CACHE_NOT_LOADED) {
                SETERRORFROMMYERROR;
                return nil;
            }
            ret = [self lockedActualItemsByNameInDirectory:thePath targetConnectionDelegate:theTCD error:error];
        }
    } else {
        ret = [self lockedActualItemsByNameInDirectory:thePath targetConnectionDelegate:theTCD error:error];
    }
    return ret;
}
- (NSDictionary *)lockedActualItemsByNameInDirectory:(NSString *)thePath targetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD error:(NSError **)error {
    NSDictionary *ret = nil;
    NSError *myError = nil;
    Item *directoryItem = nil;
    if ([itemFS usesFolderIds]) {
        directoryItem = [self lockedItemAtPath:thePath targetConnectionDelegate:theTCD error:&myError];
        if (directoryItem == nil) {
            HSLogDebug(@"itemAtPath returned nil for directoryItem %@; error=%@", thePath, myError);
            if ([myError code] != ERROR_NOT_FOUND) {
                SETERRORFROMMYERROR;
                return nil;
            }
            ret = [NSDictionary dictionary];
        }
    }
    if (directoryItem != nil || ![itemFS usesFolderIds]) {
        HSLogDetail(@"getting items in directory %@:%@", [itemFS itemFSDescription], thePath);
        BOOL duplicatesWereMerged = NO;
        ret = [itemFS itemsByNameInDirectoryItem:directoryItem path:thePath targetConnectionDelegate:theTCD duplicatesWereMerged:&duplicatesWereMerged error:error];
        if (ret == nil) {
            return nil;
        }
        if (duplicatesWereMerged) {
            // Delete all cache data for all subdirectories.
            if (![self lockedClearCachedItemsForDirectory:thePath error:error]) {
                return nil;
            }
        }
    }
    
    if (![self lockedCacheItemsByName:ret forDirectory:thePath error:&myError]) {
        HSLogError(@"error caching items for %@: %@", thePath, myError);
    }
    return ret;
}
- (BOOL)lockedRemoveItemAtPath:(NSString *)thePath targetConnectionDelegate:(id<TargetConnectionDelegate>)theTCD error:(NSError **)error {
    NSError *myError = nil;
    Item *item = [self lockedItemAtPath:thePath targetConnectionDelegate:theTCD error:&myError];
    if (item == nil) {
        if ([myError code] != ERROR_NOT_FOUND) {
            SETERRORFROMMYERROR;
            return NO;
        }
        return YES;
    }
    return [self lockedRemoveItem:item atPath:thePath targetConnectionDelegate:theTCD error:error];
}
- (BOOL)lockedRemoveItem:(Item *)theItem atPath:(NSString *)thePath targetConnectionDelegate:(id<TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    if (theItem.isDirectory) {
        if (![itemFS canRemoveDirectoriesAtomically]) {
            // Recursively delete the child items.
            
            HSLogDetail(@"removing objects in directory %@:%@", [itemFS itemFSDescription], thePath);
            NSDictionary *itemsByName = [self lockedItemsByNameInDirectory:thePath useCachedData:YES targetConnectionDelegate:theDelegate error:error];
            if (itemsByName == nil) {
                return NO;
            }
            NSMutableDictionary *childItemsByPath = [NSMutableDictionary dictionary];
            for (Item *childItem in [itemsByName allValues]) {
                NSString *childPath = [thePath stringByAppendingPathComponent:childItem.name];
                if (childItem.isDirectory) {
                    if (![self lockedRemoveItem:childItem atPath:childPath targetConnectionDelegate:theDelegate error:error]) {
                        return NO;
                    }
                } else {
                    [childItemsByPath setObject:childItem forKey:childPath];
                    if (![self lockedRemoveCachedItemWithName:childItem.name inDirectory:thePath error:error]) {
                        return NO;
                    }
                }
            }
            
            // ItemFS can't remove the whole directory in one go, so delete the files using multiple threads.
            NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
            ItemFSFileDeleter *deleter = [[[ItemFSFileDeleter alloc] initWithItemFS:itemFS itemsByPath:childItemsByPath targetConnectionDelegate:theDelegate] autorelease];
            [deleter waitForCompletion];
            [pool drain];
        } else {
            // Clear everything within the directory from the cache.
            if (![self lockedClearCachedItemsForDirectory:thePath error:error]) {
                return NO;
            }
        }
        
        // Delete the directory itself.
        NSString *parentDir = [thePath stringByDeletingLastPathComponent];
        NSError *myError = nil;
        Item *theParentDirectoryItem = [self lockedItemAtPath:parentDir targetConnectionDelegate:theDelegate error:&myError];
        if (theParentDirectoryItem == nil) {
            if ([myError code] != ERROR_NOT_FOUND) {
                SETERRORFROMMYERROR;
                return NO;
            }
        } else {
            HSLogDetail(@"removing directory %@:%@", [itemFS itemFSDescription], thePath);
            if (![itemFS removeDirectoryItem:theItem inDirectoryItem:theParentDirectoryItem itemPath:thePath targetConnectionDelegate:theDelegate error:error]) {
                return NO;
            }
        }

        // Remove the directory from the cache.
        if (![self lockedRemoveCachedItemWithName:theItem.name inDirectory:parentDir error:&myError]) {
            if ([myError code] != ERROR_CACHE_NOT_LOADED) {
                SETERRORFROMMYERROR;
                return NO;
            }
        }
    } else {
        HSLogDetail(@"removing file %@:%@", [itemFS itemFSDescription], thePath);

        // Remove the file itself.
        if (![itemFS removeFileItem:theItem itemPath:thePath targetConnectionDelegate:theDelegate error:error]) {
            return NO;
        }
        
        // Remove the file from the cache.
        NSError *myError = nil;
        if (![self lockedRemoveCachedItemWithName:theItem.name inDirectory:[thePath stringByDeletingLastPathComponent] error:&myError]) {
            if ([myError code] != ERROR_CACHE_NOT_LOADED) {
                SETERRORFROMMYERROR;
                return NO;
            }
        }
        
    }
    return YES;
}
- (Item *)lockedCreateDirectoryAtPath:(NSString *)path targetConnectionDelegate:(id<TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    NSError *myError = nil;
    Item *parentDirItem = nil;
    if ([itemFS usesFolderIds]) {
        NSString *parentDir = [path stringByDeletingLastPathComponent];
        HSLogDebug(@"attempting to get parent dir item %@", parentDir);
        parentDirItem = [self lockedItemAtPath:parentDir targetConnectionDelegate:theDelegate error:&myError];
        if (parentDirItem == nil) {
            HSLogDebug(@"itemAtPath for parent dir item %@ returned nil; error=%@", parentDir, myError);
            if ([myError code] != ERROR_NOT_FOUND) {
                SETERRORFROMMYERROR;
                return nil;
            }
            HSLogDebug(@"attempting to create parent dir %@", parentDir);
            parentDirItem = [self lockedCreateDirectoryAtPath:parentDir targetConnectionDelegate:theDelegate error:error];
            if (parentDirItem == nil) {
                if (error != NULL) {
                    HSLogDebug(@"create parent dir %@ failed; error=%@", parentDir, *error);
                }
                return nil;
            }
        } else {
            HSLogDebug(@"found parent dir %@", parentDir);
        }
    }
    HSLogDetail(@"creating directory %@:%@", [itemFS itemFSDescription], path);
    Item *item = [itemFS createDirectoryWithName:[path lastPathComponent] inDirectoryItem:parentDirItem itemPath:path targetConnectionDelegate:theDelegate error:error];
    if (item == nil) {
        return nil;
    }
    
    if (![itemFS enforcesUniqueFilenames]) {
        // We may have created an additional directory with the same name (only Google Drive returns false for enforcesUniqueFilenames).
        if (![self lockedAddItemToCache:item inDirectory:[path stringByDeletingLastPathComponent] error:&myError]) {
            if ([myError code] != ERROR_ITEM_EXISTS) {
                SETERRORFROMMYERROR;
                return nil;
            }
            
            // Delete our directory since it's a duplicate.
            if (![itemFS removeItemById:item.itemId targetConnectionDelegate:theDelegate error:&myError]) {
                SETERRORFROMMYERROR;
                HSLogError(@"failed to delete the duplicate directory %@ we just created: %@", path, myError);
                return nil;
            }
            
            Item *foundItem = [[myError userInfo] objectForKey:@"previouslyExistingItem"];
            NSAssert(foundItem != nil, @"foundItem may not be nil");
            item = foundItem;
        }
    } else {
        // We overwrote it, so overwrite the item in the cache too.
        if (![self lockedAddOrReplaceItemInCache:item inDirectory:[path stringByDeletingLastPathComponent] error:&myError]) {
            if ([myError code] != ERROR_CACHE_NOT_LOADED) {
                SETERRORFROMMYERROR;
                return nil;
            }
        }
    }
    return item;
}



#pragma mark cache
- (BOOL)lockedAddItemToCache:(Item *)theItem inDirectory:(NSString *)theDirectory error:(NSError **)error {
    if ([itemFS usesFolderIds] && [theItem itemId] == nil) {
        SETNSERROR([self remoteFSErrorDomain], -1, @"failed to add %@ to the cache of %@: item id may not be nil", [theItem name], theDirectory);
        return NO;
    }
    
    return [[ItemsDB sharedItemsDB] addItem:theItem inDirectory:theDirectory targetUUID:cacheUUID error:error];
}
- (BOOL)lockedMoveCachedItem:(Item *)theItem fromDirectory:(NSString *)theFromDirectory toDirectory:(NSString *)theToDirectory error:(NSError **)error {
    return [[ItemsDB sharedItemsDB] moveItem:theItem fromDirectory:theFromDirectory toDirectory:theToDirectory targetUUID:cacheUUID error:error];
}
- (BOOL)lockedAddOrReplaceItemInCache:(Item *)theItem inDirectory:(NSString *)theDirectory error:(NSError **)error {
    if ([itemFS usesFolderIds] && [theItem itemId] == nil) {
        SETNSERROR([self remoteFSErrorDomain], -1, @"failed to add %@ to the cache of %@: item id may not be nil", [theItem name], theDirectory);
        return NO;
    }
    NSError *myError = nil;
    BOOL ret = [[ItemsDB sharedItemsDB] addOrReplaceItem:theItem inDirectory:theDirectory targetUUID:cacheUUID error:&myError];
    if (!ret && [myError code] == ERROR_CACHE_NOT_LOADED) {
        ret = YES;
    }
    return ret;
}
- (BOOL)lockedRemoveCachedItemWithName:(NSString *)theItemName inDirectory:(NSString *)theDirectory error:(NSError **)error {
    return [[ItemsDB sharedItemsDB] removeItemWithName:theItemName inDirectory:theDirectory targetUUID:cacheUUID error:error];
}
- (BOOL)lockedClearCachedItemsForDirectory:(NSString *)theDirectory error:(NSError **)error {
    return [[ItemsDB sharedItemsDB] clearItemsByNameInDirectory:theDirectory targetUUID:cacheUUID error:error];
}
- (BOOL)lockedClearAllCachedItems:(NSError **)error {
    return [[ItemsDB sharedItemsDB] destroyForTargetUUID:cacheUUID error:error];
}
- (BOOL)lockedCacheItemsByName:(NSDictionary *)theItemsByName forDirectory:(NSString *)theDirectory error:(NSError **)error {
        return [[ItemsDB sharedItemsDB] setItemsByName:theItemsByName inDirectory:theDirectory targetUUID:cacheUUID error:error];
}
- (Item *)lockedCachedItemAtPath:(NSString *)thePath error:(NSError **)error {
    Item *ret = [[ItemsDB sharedItemsDB] itemAtPath:thePath targetUUID:cacheUUID error:error];
    return ret;
}
- (NSDictionary *)lockedCachedItemsByNameForDirectory:(NSString *)theDirectory error:(NSError **)error {
    NSDictionary *ret = [[ItemsDB sharedItemsDB] itemsByNameInDirectory:theDirectory targetUUID:cacheUUID error:error];
    return ret;
}
@end
