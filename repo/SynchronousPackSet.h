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



@class PackSet;
@class Fark;
#import "StorageType.h"
@class PackId;
@protocol PackSetActivityListener;
@class PackIndexEntry;


@interface SynchronousPackSet : NSObject {
    PackSet *packSet;
    NSLock *lock;
}
- (id)initWithFark:(Fark *)theFark
       storageType:(StorageType)theStorageType
       packSetName:(NSString *)thePackSetName
  cachePackFilesToDisk:(BOOL)theCachePackFilesToDisk
  activityListener:(id<PackSetActivityListener>)theActivityListener
             error:(NSError **)error;

- (NSString *)errorDomain;

- (NSString *)packSetName;
- (StorageType)storageType;
- (NSNumber *)sizeOfBlobInCacheForSHA1:(NSString *)sha1 error:(NSError **)error;
- (NSNumber *)containsBlobInCacheForSHA1:(NSString *)sha1 error:(NSError **)error;
- (PackId *)packIdForSHA1:(NSString *)theSHA1 error:(NSError **)error;
- (NSData *)dataForSHA1:(NSString *)sha1 withRetry:(BOOL)retry error:(NSError **)error;
- (BOOL)putData:(NSData *)theData sha1:(NSString *)sha1 error:(NSError **)error;
- (BOOL)commit:(NSError **)error;
- (BOOL)restorePackForBlobWithSHA1:(NSString *)theSHA1 forDays:(NSUInteger)theDays tier:(int)theGlacierRetrievalTier alreadyRestoredOrRestoring:(BOOL *)alreadyRestoredOrRestoring error:(NSError **)error;
- (NSNumber *)isObjectDownloadableForSHA1:(NSString *)theSHA1 error:(NSError **)error;
- (BOOL)consolidate:(NSError **)error;
- (BOOL)clearCache:(NSError **)error;
- (void)reloadCache;
- (BOOL)deleteBlobForSHA1:(NSString *)theSHA1 error:(NSError **)error;
- (PackIndexEntry *)packIndexEntryForSHA1:(NSString *)theSHA1 error:(NSError **)error;
@end
