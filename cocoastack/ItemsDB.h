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



#import "CWLSynthesizeSingleton.h"
@class Item;
@class FMDatabase;


@interface ItemsDB : NSObject {
    NSLock *lock;
    NSMutableDictionary *targetItemsDBsByUUID;
}
CWL_DECLARE_SINGLETON_FOR_CLASS(ItemsDB)

+ (NSString *)errorDomain;

- (Item *)itemAtPath:(NSString *)thePath targetUUID:(NSString *)theTargetUUID error:(NSError **)error;
- (NSNumber *)cacheIsLoadedForDirectory:(NSString *)theDirectory targetUUID:(NSString *)theTargetUUID error:(NSError **)error;
- (NSMutableDictionary *)itemsByNameInDirectory:(NSString *)theDirectory targetUUID:(NSString *)theTargetUUID error:(NSError **)error;
- (BOOL)setItemsByName:(NSDictionary *)theItemsByName inDirectory:(NSString *)theDirectory targetUUID:(NSString *)theTargetUUID error:(NSError **)error;
- (BOOL)clearItemsByNameInDirectory:(NSString *)theDirectory targetUUID:(NSString *)theTargetUUID error:(NSError **)error;
- (BOOL)destroyForTargetUUID:(NSString *)theTargetUUID error:(NSError **)error;
- (BOOL)addItem:(Item *)theItem inDirectory:(NSString *)theDirectory targetUUID:(NSString *)theTargetUUID error:(NSError **)error;
- (BOOL)addOrReplaceItem:(Item *)theItem inDirectory:(NSString *)theDirectory targetUUID:(NSString *)theTargetUUID error:(NSError **)error;
- (BOOL)removeItemWithName:(NSString *)theItemName inDirectory:(NSString *)theDirectory targetUUID:(NSString *)theTargetUUID error:(NSError **)error;
- (BOOL)moveItem:(Item *)theItem fromDirectory:(NSString *)theFromDirectory toDirectory:(NSString *)theToDirectory targetUUID:(NSString *)theTargetUUID error:(NSError **)error;
- (BOOL)clearReferenceCountsForTargetUUID:(NSString *)theTargetUUID error:(NSError **)error;
- (BOOL)setReferenceCountOfFileAtPath:(NSString *)thePath targetUUID:(NSString *)theTargetUUID error:(NSError **)error;
- (NSNumber *)totalSizeOfReferencedFilesInDirectory:(NSString *)theDir targetUUID:(NSString *)theTargetUUID error:(NSError **)error;
- (NSArray *)pathsOfUnreferencedFilesInDirectory:(NSString *)theDir targetUUID:(NSString *)theTargetUUID error:(NSError **)error;
@end
