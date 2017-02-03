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



#ifndef Arq_ItemFS_h
#define Arq_ItemFS_h

@protocol DataTransferDelegate;
@protocol TargetConnectionDelegate;
@class Item;


@protocol ItemFS <NSObject>
- (NSString *)itemFSDescription;
- (BOOL)canRemoveDirectoriesAtomically;
- (BOOL)usesFolderIds;
- (BOOL)enforcesUniqueFilenames;
- (Item *)rootDirectoryItemWithTargetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD error:(NSError **)error;
- (NSDictionary *)itemsByNameInDirectoryItem:(Item *)theItem path:(NSString *)theDirectoryPath targetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD duplicatesWereMerged:(BOOL *)duplicatesWereMerged error:(NSError **)error;
- (Item *)createDirectoryWithName:(NSString *)theName inDirectoryItem:(Item *)theDirectoryItem itemPath:(NSString *)thePath targetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD error:(NSError **)error;
- (BOOL)removeDirectoryItem:(Item *)theItem inDirectoryItem:(Item *)theParentDirectoryItem itemPath:(NSString *)thePath targetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD error:(NSError **)error;
- (NSData *)contentsOfRange:(NSRange)theRange ofFileItem:(Item *)theItem itemPath:(NSString *)theFullPath dataTransferDelegate:(id <DataTransferDelegate>)theDTD targetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD error:(NSError **)error;
- (Item *)createFileWithData:(NSData *)theData name:(NSString *)theName inDirectoryItem:(Item *)theDirectoryItem existingItem:(Item *)theExistingItem itemPath:(NSString *)theFullPath dataTransferDelegate:(id <DataTransferDelegate>)theDTD targetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD error:(NSError **)error;
- (BOOL)moveItem:(Item *)theItem toNewName:(NSString *)theNewName fromDirectoryItem:(Item *)theFromDirectoryItem fromDirectory:(NSString *)theFromDir toDirectoryItem:(Item *)theToDirectoryItem toDirectory:(NSString *)theToDir targetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD error:(NSError **)error;
- (BOOL)removeFileItem:(Item *)theItem itemPath:(NSString *)theFullPath targetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD error:(NSError **)error;
- (NSNumber *)freeBytesAtPath:(NSString *)thePath targetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD error:(NSError **)error;
- (BOOL)updateFingerprintWithTargetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD error:(NSError **)error;
- (NSNumber *)isObjectRestoredAtPath:(NSString *)thePath targetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD error:(NSError **)error;
- (BOOL)restoreObjectAtPath:(NSString *)thePath forDays:(NSUInteger)theDays tier:(int)theGlacierRetrievalTier alreadyRestoredOrRestoring:(BOOL *)alreadyRestoredOrRestoring targetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD error:(NSError **)error;
- (BOOL)removeItemById:(NSString *)theItemId targetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD error:(NSError **)error;
@end

#endif
