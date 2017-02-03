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




#import "SynchronousPackSet.h"
#import "PackSet.h"


@implementation SynchronousPackSet
- (id)initWithFark:(Fark *)theFark
       storageType:(StorageType)theStorageType
       packSetName:(NSString *)thePackSetName
  cachePackFilesToDisk:(BOOL)theCachePackFilesToDisk
  activityListener:(id<PackSetActivityListener>)theActivityListener
             error:(NSError **)error {
    if (self = [super init]) {
        packSet = [[PackSet alloc] initWithFark:theFark
                                    storageType:theStorageType
                                    packSetName:thePackSetName
                               cachePackFilesToDisk:theCachePackFilesToDisk
                               activityListener:theActivityListener
                                          error:error];
        if (packSet == nil) {
            [self release];
            return nil;
        }
        lock = [[NSLock alloc] init];
        [lock setName:@"SynchronousPackSet lock"];
    }
    return self;
}
- (void)dealloc {
    [packSet release];
    [lock release];
    [super dealloc];
}

- (NSString *)errorDomain {
    return [packSet errorDomain];
}

- (NSString *)packSetName {
    return [packSet packSetName];
}
- (StorageType)storageType {
    return [packSet storageType];
}
- (NSNumber *)sizeOfBlobInCacheForSHA1:(NSString *)sha1 error:(NSError **)error {
    [lock lock];
    NSNumber *ret = [packSet sizeOfBlobInCacheForSHA1:sha1 error:error];
    [lock unlock];
    return ret;
}
- (NSNumber *)containsBlobInCacheForSHA1:(NSString *)sha1 error:(NSError **)error {
    [lock lock];
    NSNumber *ret = [packSet containsBlobInCacheForSHA1:sha1 error:error];
    [lock unlock];
    return ret;
}
- (PackId *)packIdForSHA1:(NSString *)theSHA1 error:(NSError **)error {
    [lock lock];
    PackId *ret = [packSet packIdForSHA1:theSHA1 error:error];
    [lock unlock];
    return ret;
}
- (NSData *)dataForSHA1:(NSString *)sha1 withRetry:(BOOL)retry error:(NSError **)error {
    [lock lock];
    NSData *ret = [packSet dataForSHA1:sha1 withRetry:retry error:error];
    [lock unlock];
    return ret;
}
- (BOOL)putData:(NSData *)theData sha1:(NSString *)sha1 error:(NSError **)error {
    [lock lock];
    BOOL ret = [packSet putData:theData sha1:sha1 error:error];
    [lock unlock];
    return ret;
}
- (BOOL)commit:(NSError **)error {
    [lock lock];
    BOOL ret = [packSet commit:error];
    [lock unlock];
    return ret;
}
- (BOOL)restorePackForBlobWithSHA1:(NSString *)theSHA1 forDays:(NSUInteger)theDays tier:(int)theGlacierRetrievalTier alreadyRestoredOrRestoring:(BOOL *)alreadyRestoredOrRestoring error:(NSError **)error {
    [lock lock];
    BOOL ret = [packSet restorePackForBlobWithSHA1:theSHA1 forDays:theDays tier:theGlacierRetrievalTier alreadyRestoredOrRestoring:alreadyRestoredOrRestoring error:error];
    [lock unlock];
    return ret;
}
- (NSNumber *)isObjectDownloadableForSHA1:(NSString *)theSHA1 error:(NSError **)error {
    [lock lock];
    NSNumber *ret = [packSet isObjectDownloadableForSHA1:theSHA1 error:error];
    [lock unlock];
    return ret;
}
- (BOOL)consolidate:(NSError **)error {
    [lock lock];
    BOOL ret = [packSet consolidate:error];
    [lock unlock];
    return ret;
}
- (BOOL)clearCache:(NSError **)error {
    [lock lock];
    BOOL ret = [packSet clearCache:error];
    [lock unlock];
    return ret;
}
- (void)reloadCache {
    [lock lock];
    [packSet reloadCache];
    [lock unlock];
}
- (BOOL)deleteBlobForSHA1:(NSString *)theSHA1 error:(NSError **)error {
    [lock lock];
    BOOL ret = [packSet deleteBlobForSHA1:theSHA1 error:error];
    [lock unlock];
    return ret;
}
- (PackIndexEntry *)packIndexEntryForSHA1:(NSString *)theSHA1 error:(NSError **)error {
    [lock lock];
    PackIndexEntry *ret = [packSet packIndexEntryForSHA1:theSHA1 error:error];
    [lock unlock];
    return ret;
}
@end
