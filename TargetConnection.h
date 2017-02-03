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



@class Target;
#import "RemoteFS.h"
@class Item;
@protocol DataTransferDelegate;
@protocol DeleteDelegate;


@protocol TargetConnectionDelegate <NSObject>
- (BOOL)targetConnectionShouldRetryOnTransientError:(NSError **)error;
@end


@interface TargetConnection : NSObject {
    Target *target;
    NSString *pathPrefix;
    NSMutableDictionary *remoteFSByThreadId;
    NSLock *lock;
}
- (id)initWithTarget:(Target *)theTarget;

- (BOOL)updateFingerprintWithTargetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD error:(NSError **)error;

- (Item *)itemAtPath:(NSString *)thePath targetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD error:(NSError **)error;
- (NSDictionary *)itemsByNameAtPath:(NSString *)thePath targetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD error:(NSError **)error;

- (NSArray *)computerUUIDsWithDelegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error;
- (NSArray *)bucketUUIDsForComputerUUID:(NSString *)theComputerUUID deleted:(BOOL)deleted delegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error;

- (NSData *)bucketPlistDataForComputerUUID:(NSString *)theComputerUUID bucketUUID:(NSString *)theBucketUUID deleted:(BOOL)deleted delegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error;
- (BOOL)saveBucketPlistData:(NSData *)theData forComputerUUID:(NSString *)theComputerUUID bucketUUID:(NSString *)theBucketUUID deleted:(BOOL)deleted delegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error;
- (BOOL)deleteBucketPlistDataForComputerUUID:(NSString *)theComputerUUID bucketUUID:(NSString *)theBucketUUID deleted:(BOOL)deleted delegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error;

- (NSData *)computerInfoForComputerUUID:(NSString *)theComputerUUID delegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error;
- (BOOL)saveComputerInfo:(NSData *)theData forComputerUUID:(NSString *)theComputerUUID delegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error;

- (BOOL)deleteObjectsForComputerUUID:(NSString *)theComputerUUID delegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error;

- (NSNumber *)fileExistsAtPath:(NSString *)thePath dataSize:(unsigned long long *)theDataSize delegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error;
- (NSData *)contentsOfFileAtPath:(NSString *)thePath delegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error;
- (NSData *)contentsOfRange:(NSRange)theRange ofFileAtPath:(NSString *)thePath delegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error;
- (BOOL)writeData:(NSData *)theData toFileAtPath:(NSString *)thePath dataTransferDelegate:(id <DataTransferDelegate>)theDelegate targetConnectionDelegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error;
- (BOOL)removeItemAtPath:(NSString *)thePath delegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error;

- (NSString *)checksumOfFileAtPath:(NSString *)thePath delegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error;

- (NSNumber *)aggregateSizeOfDirectoryAtPath:(NSString *)thePath delegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error;
- (NSNumber *)isObjectRestoredAtPath:(NSString *)thePath delegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error;
- (BOOL)restoreObjectAtPath:(NSString *)thePath forDays:(NSUInteger)theDays tier:(int)theGlacierRetrievalTier alreadyRestoredOrRestoring:(BOOL *)alreadyRestoredOrRestoring delegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error;

- (NSData *)saltDataForComputerUUID:(NSString *)theComputerUUID delegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error;
- (BOOL)setSaltData:(NSData *)theData forComputerUUID:(NSString *)theComputerUUID delegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error;
- (BOOL)deleteSaltDataForComputerUUID:(NSString *)theComputerUUID delegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error;

- (NSData *)encryptionDataForComputerUUID:(NSString *)theComputerUUID encryptionVersion:(int)theEncryptionVersion delegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error;
- (BOOL)setEncryptionData:(NSData *)theData forComputerUUID:(NSString *)theComputerUUID encryptionVersion:(int)theEncryptionVersion delegate:(id<TargetConnectionDelegate>)theDelegate error:(NSError **)error;

- (NSDictionary *)pathsBySHA1WithIsGlacier:(BOOL)theIsGlacier computerUUID:(NSString *)theComputerUUID delegate:(id<TargetConnectionDelegate>)theDelegate error:(NSError **)error;

- (NSNumber *)freeBytesAtPath:(NSString *)thePath targetConnectionDelegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error;

- (BOOL)clearCachedItemsForDirectory:(NSString *)theDirectory error:(NSError **)error;
- (BOOL)clearAllCachedData:(NSError **)error;

- (NSNumber *)chunkerVersionForComputerUUID:(NSString *)theComputerUUID delegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error;
- (BOOL)setChunkerVersion:(NSInteger)theChunkerVersion forComputerUUID:(NSString *)theComputerUUID delegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error;
@end
