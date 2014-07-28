/*
 Copyright (c) 2009-2014, Stefan Reitshamer http://www.haystacksoftware.com
 
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


#import "StorageType.h"
@protocol Fark;
@class PackBuilder;
@class PackId;


@interface PackSet : NSObject {
    id <Fark> fark;
    StorageType storageType;
    NSString *packSetName;
    BOOL savePacksToCache;
    uid_t targetUID;
    gid_t targetGID;
    BOOL loadExistingMutablePackFiles;
    NSMutableDictionary *packIndexEntriesByObjectSHA1;
}


+ (unsigned long long)maxPackFileSizeMB;
+ (unsigned long long)maxPackItemSizeBytes;

- (id)initWithFark:(id <Fark>)theFark
       storageType:(StorageType)theStorageType
       packSetName:(NSString *)thePackSetName
  savePacksToCache:(BOOL)theSavePacksToCache
         targetUID:(uid_t)theTargetUID
         targetGID:(gid_t)theTargetGID
loadExistingMutablePackFiles:(BOOL)theLoadExistingMutablePackFiles;

- (NSString *)errorDomain;

- (NSString *)packSetName;
- (NSNumber *)containsBlobForSHA1:(NSString *)sha1 dataSize:(unsigned long long *)dataSize error:(NSError **)error;
- (PackId *)packIdForSHA1:(NSString *)theSHA1 error:(NSError **)error;
- (NSData *)dataForSHA1:(NSString *)sha1 withRetry:(BOOL)retry error:(NSError **)error;
- (BOOL)restorePackForBlobWithSHA1:(NSString *)theSHA1 forDays:(NSUInteger)theDays alreadyRestoredOrRestoring:(BOOL *)alreadyRestoredOrRestoring error:(NSError **)error;
- (NSNumber *)isObjectDownloadableForSHA1:(NSString *)theSHA1 error:(NSError **)error;
@end
