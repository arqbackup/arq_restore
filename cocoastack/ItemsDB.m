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



#import "ItemsDB.h"
#import "TargetItemsDB.h"


@implementation ItemsDB
CWL_SYNTHESIZE_SINGLETON_FOR_CLASS(ItemsDB)

+ (NSString *)errorDomain {
    return @"ItemsDBErrorDomain";
}


- (id)init {
    if (self = [super init]) {
        lock = [[NSLock alloc] init];
        [lock setName:@"ItemsDB lock"];
        targetItemsDBsByUUID = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (Item *)itemAtPath:(NSString *)thePath targetUUID:(NSString *)theTargetUUID error:(NSError **)error {
    [lock lock];
    Item *ret = [[self targetItemsDBForTargetUUID:theTargetUUID error:error] itemAtPath:thePath error:error];
    [lock unlock];
    return ret;
}
- (NSNumber *)cacheIsLoadedForDirectory:(NSString *)theDirectory targetUUID:(NSString *)theTargetUUID error:(NSError **)error {
    NSNumber *ret = nil;
    [lock lock];
    TargetItemsDB *tidb = [self targetItemsDBForTargetUUID:theTargetUUID error:error];
    if (tidb != nil) {
        ret = [tidb cacheIsLoadedForDirectory:theDirectory error:error];
    }
    [lock unlock];
    return ret;
}
- (NSMutableDictionary *)itemsByNameInDirectory:(NSString *)theDirectory targetUUID:(NSString *)theTargetUUID error:(NSError **)error {
    [lock lock];
    NSMutableDictionary *ret = [[self targetItemsDBForTargetUUID:theTargetUUID error:error] itemsByNameInDirectory:theDirectory error:error];
    [lock unlock];
    return ret;
}
- (BOOL)setItemsByName:(NSDictionary *)theItemsByName inDirectory:(NSString *)theDirectory targetUUID:(NSString *)theTargetUUID error:(NSError **)error {
    [lock lock];
    BOOL ret = [[self targetItemsDBForTargetUUID:theTargetUUID error:error] setItemsByName:theItemsByName inDirectory:theDirectory error:error];
    [lock unlock];
    return ret;
}
- (BOOL)clearItemsByNameInDirectory:(NSString *)theDirectory targetUUID:(NSString *)theTargetUUID error:(NSError **)error {
    [lock lock];
    BOOL ret = [[self targetItemsDBForTargetUUID:theTargetUUID error:error] clearItemsByNameInDirectory:theDirectory error:error];
    [lock unlock];
    return ret;
}


- (BOOL)destroyForTargetUUID:(NSString *)theTargetUUID error:(NSError **)error {
    [lock lock];
    BOOL ret = [[self targetItemsDBForTargetUUID:theTargetUUID error:error] destroy:error];
    [targetItemsDBsByUUID removeObjectForKey:theTargetUUID];
    [lock unlock];
    return ret;
}

- (BOOL)addItem:(Item *)theItem inDirectory:(NSString *)theDirectory targetUUID:(NSString *)theTargetUUID error:(NSError **)error {
    [lock lock];
    BOOL ret = [[self targetItemsDBForTargetUUID:theTargetUUID error:error] addItem:theItem inDirectory:theDirectory error:error];
    [lock unlock];
    return ret;
}
- (BOOL)addOrReplaceItem:(Item *)theItem inDirectory:(NSString *)theDirectory targetUUID:(NSString *)theTargetUUID error:(NSError **)error {
    [lock lock];
    BOOL ret = [[self targetItemsDBForTargetUUID:theTargetUUID error:error] addOrReplaceItem:theItem inDirectory:theDirectory error:error];
    [lock unlock];
    return ret;
}
- (BOOL)removeItemWithName:(NSString *)theItemName inDirectory:(NSString *)theDirectory targetUUID:(NSString *)theTargetUUID error:(NSError **)error {
    [lock lock];
    BOOL ret = [[self targetItemsDBForTargetUUID:theTargetUUID error:error] removeItemWithName:theItemName inDirectory:theDirectory error:error];
    [lock unlock];
    return ret;
}
- (BOOL)moveItem:(Item *)theItem fromDirectory:(NSString *)theFromDirectory toDirectory:(NSString *)theToDirectory targetUUID:(NSString *)theTargetUUID error:(NSError **)error {
    [lock lock];
    BOOL ret = [[self targetItemsDBForTargetUUID:theTargetUUID error:error] moveItem:theItem fromDirectory:theFromDirectory toDirectory:theToDirectory error:error];
    [lock unlock];
    return ret;
}

- (BOOL)clearReferenceCountsForTargetUUID:(NSString *)theTargetUUID error:(NSError **)error {
    [lock lock];
    BOOL ret = [[self targetItemsDBForTargetUUID:theTargetUUID error:error] clearReferenceCounts:error];
    [lock unlock];
    return ret;
}
- (BOOL)setReferenceCountOfFileAtPath:(NSString *)thePath targetUUID:(NSString *)theTargetUUID error:(NSError **)error {
    [lock lock];
    BOOL ret = [[self targetItemsDBForTargetUUID:theTargetUUID error:error] setReferenceCountOfFileAtPath:thePath error:error];
    [lock unlock];
    return ret;
}
- (NSNumber *)totalSizeOfReferencedFilesInDirectory:(NSString *)theDirectory targetUUID:(NSString *)theTargetUUID error:(NSError **)error {
    [lock lock];
    NSNumber *ret = [[self targetItemsDBForTargetUUID:theTargetUUID error:error] totalSizeOfReferencedFilesInDirectory:theDirectory error:error];
    [lock unlock];
    return ret;
}
- (NSArray *)pathsOfUnreferencedFilesInDirectory:(NSString *)theDirectory targetUUID:(NSString *)theTargetUUID error:(NSError **)error {
    [lock lock];
    NSArray *ret = [[self targetItemsDBForTargetUUID:theTargetUUID error:error] pathsOfUnreferencedFilesInDirectory:theDirectory error:error];
    [lock unlock];
    return ret;
}
- (TargetItemsDB *)targetItemsDBForTargetUUID:(NSString *)theTargetUUID error:(NSError **)error {
    TargetItemsDB *ret = [targetItemsDBsByUUID objectForKey:theTargetUUID];
    if (ret == nil) {
        ret = [[[TargetItemsDB alloc] initWithTargetUUID:theTargetUUID error:error] autorelease];
        if (ret == nil) {
            return nil;
        }
        [targetItemsDBsByUUID setObject:ret forKey:theTargetUUID];
    }
    return ret;
}
@end
