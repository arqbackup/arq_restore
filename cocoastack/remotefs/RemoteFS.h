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



#import "ItemFS.h"
@protocol DataTransferDelegate;
@protocol TargetConnectionDelegate;
@class Item;
@protocol DeleteDelegate;


@interface RemoteFS : NSObject {
    NSString *lockFilePath;
    id <ItemFS> itemFS;
    NSString *cacheUUID;
}
- (id)initWithItemFS:(id <ItemFS>)theItemFS cacheUUID:(NSString *)theCacheUUID;

- (BOOL)updateFingerprintWithTargetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD error:(NSError **)error;

- (Item *)itemAtPath:(NSString *)thePath targetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD error:(NSError **)error;
- (NSDictionary *)itemsByNameInDirectory:(NSString *)thePath targetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD error:(NSError **)error;
- (NSDictionary *)itemsByNameInDirectory:(NSString *)thePath useCachedData:(BOOL)theUseCachedData targetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD error:(NSError **)error;
- (NSData *)contentsOfFileAtPath:(NSString *)thePath dataTransferDelegate:(id <DataTransferDelegate>)theDTD targetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD error:(NSError **)error;
- (NSData *)contentsOfRange:(NSRange)theRange ofFileAtPath:(NSString *)thePath dataTransferDelegate:(id <DataTransferDelegate>)theDTD targetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD error:(NSError **)error;
- (Item *)createFileAtomicallyWithData:(NSData *)theData atPath:(NSString *)thePath dataTransferDelegate:(id <DataTransferDelegate>)theDTD targetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD error:(NSError **)error;
- (BOOL)moveItemAtPath:(NSString *)thePath toPath:(NSString *)theDestinationPath targetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD error:(NSError **)error;
- (BOOL)removeItemAtPath:(NSString *)theSourcePath targetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD error:(NSError **)error;
- (Item *)createDirectoryAtPath:(NSString *)path targetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD error:(NSError **)error;
- (NSNumber *)isObjectRestoredAtPath:(NSString *)thePath targetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD error:(NSError **)error;
- (BOOL)restoreObjectAtPath:(NSString *)thePath forDays:(NSUInteger)theDays tier:(int)theGlacierRetrievalTier alreadyRestoredOrRestoring:(BOOL *)alreadyRestoredOrRestoring targetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD error:(NSError **)error;

- (NSNumber *)freeBytesAtPath:(NSString *)thePath targetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD error:(NSError **)error;

- (BOOL)clearCacheForPath:(NSString *)thePath error:(NSError **)error;
- (BOOL)clearCache:(NSError **)error;
@end
