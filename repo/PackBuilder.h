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



#import "StorageType.h"
@class Fark;
@class PackId;


@interface PackBuilder : NSObject {
    Fark *fark;
    StorageType storageType;
    NSString *packSetName;
    BOOL cachePackFilesToDisk;
//    PackId *sourcePackId;
    NSMutableData *buffer;
    NSMutableDictionary *entriesBySHA1;
    BOOL modified;
}

//- (id)initWithFark:(Fark *)theFark
//       storageType:(StorageType)theStorageType
//       packSetName:(NSString *)thePackSetName
//            buffer:(NSMutableData *)theBuffer
//      sourcePackId:(PackId *)theSourcePackId
//  cachePackFilesToDisk:(BOOL)theCachePackFilesToDisk
//             error:(NSError **)error;

- (id)initWithFark:(Fark *)theFark
       storageType:(StorageType)theStorageType
       packSetName:(NSString *)thePackSetName
            buffer:(NSMutableData *)theBuffer
  cachePackFilesToDisk:(BOOL)theCachePackFilesToDisk;

- (NSString *)errorDomain;
- (BOOL)containsObjectForSHA1:(NSString *)sha1;
- (NSData *)dataForSHA1:(NSString *)theSHA1 error:(NSError **)error;
- (void)addData:(NSData *)theData forSHA1:(NSString *)sha1;
- (void)removeDataForSHA1:(NSString *)sha1;
- (uint64_t)size;
- (NSArray *)sha1s;
- (BOOL)isModified;
- (PackId *)commit:(NSError **)error;
//- (PackId *)sourcePackId;
@end
