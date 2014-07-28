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


#import "BlobKey.h"
#import "BufferedInputStream.h"
#import "StringIO.h"
#import "BooleanIO.h"
#import "IntegerIO.h"
#import "NSObject_extra.h"
#import "NSString_extra.h"
#import "SHA1Hash.h"


@implementation BlobKey
- (id)initWithSHA1:(NSString *)theSHA1 archiveId:(NSString *)theArchiveId archiveSize:(uint64_t)theArchiveSize archiveUploadedDate:(NSDate *)theArchiveUploadedDate compressed:(BOOL)isCompressed error:(NSError **)error {
    if (self = [super init]) {
        storageType = StorageTypeGlacier;
        
        NSData *sha1Data = [theSHA1 hexStringToData:error];
        if (sha1Data == nil) {
            [self release];
            return nil;
        }
        if ([sha1Data length] != 20) {
            SETNSERROR(@"BlobKeyErrorDomain", -1, @"invalid sha1 %@ for BlobKey (must be 20 bytes)", theSHA1);
            [self release];
            return nil;
        }
        sha1Bytes = (unsigned char *)malloc(20);
        memcpy(sha1Bytes, [sha1Data bytes], 20);
        
        archiveId = [theArchiveId retain];
        archiveSize = theArchiveSize;
        archiveUploadedDate = [theArchiveUploadedDate retain];
        compressed = isCompressed;
    }
    return self;
}
- (id)initWithSHA1:(NSString *)theSHA1 storageType:(StorageType)theStorageType stretchEncryptionKey:(BOOL)isStretchedKey compressed:(BOOL)isCompressed error:(NSError **)error {
    if (self = [super init]) {
        storageType = theStorageType;
        
        NSData *sha1Data = [theSHA1 hexStringToData:error];
        if (sha1Data == nil) {
            [self release];
            return nil;
        }
        if ([sha1Data length] != 20) {
            SETNSERROR(@"BlobKeyErrorDomain", -1, @"invalid sha1 %@ for BlobKey (must be 20 bytes)", theSHA1);
            [self release];
            return nil;
        }
        sha1Bytes = (unsigned char *)malloc(20);
        memcpy(sha1Bytes, [sha1Data bytes], 20);
        
        stretchEncryptionKey = isStretchedKey;
        compressed = isCompressed;
    }
    return self;
}
- (id)initWithStorageType:(StorageType)theStorageType archiveId:(NSString *)theArchiveId archiveSize:(uint64_t)theArchiveSize archiveUploadedDate:(NSDate *)theArchiveUploadedDate sha1:(NSString *)theSHA1 stretchEncryptionKey:(BOOL)isStretchedKey compressed:(BOOL)isCompressed error:(NSError **)error {
    if (self = [super init]) {
        storageType = theStorageType;
        archiveId = [theArchiveId retain];
        archiveSize = theArchiveSize;
        archiveUploadedDate = [theArchiveUploadedDate retain];
        
        NSData *sha1Data = [theSHA1 hexStringToData:error];
        if (sha1Data == nil) {
            [self release];
            return nil;
        }
        if ([sha1Data length] != 20) {
            SETNSERROR(@"BlobKeyErrorDomain", -1, @"invalid sha1 %@ for BlobKey (must be 20 bytes)", theSHA1);
            [self release];
            return nil;
        }
        sha1Bytes = (unsigned char *)malloc(20);
        memcpy(sha1Bytes, [sha1Data bytes], 20);
        
        stretchEncryptionKey = isStretchedKey;
        compressed = isCompressed;
    }
    return self;
}
- (id)initCopyOfBlobKey:(BlobKey *)theBlobKey withStorageType:(StorageType)theStorageType {
    return [[BlobKey alloc] initWithStorageType:theStorageType
                                      archiveId:[theBlobKey archiveId]
                                    archiveSize:[theBlobKey archiveSize]
                            archiveUploadedDate:[theBlobKey archiveUploadedDate]
                                      sha1Bytes:[theBlobKey sha1Bytes]
                           stretchEncryptionKey:[theBlobKey stretchEncryptionKey]
                                     compressed:[theBlobKey compressed]];
}
- (void)dealloc {
    [archiveId release];
    [archiveUploadedDate release];
    free(sha1Bytes);
    [super dealloc];
}

- (StorageType)storageType {
    return storageType;
}
- (NSString *)archiveId {
    return archiveId;
}
- (uint64_t)archiveSize {
    return archiveSize;
}
- (NSDate *)archiveUploadedDate {
    return archiveUploadedDate;
}
- (NSString *)sha1 {
    return [NSString hexStringWithBytes:sha1Bytes length:20];
}
- (unsigned char *)sha1Bytes {
    return sha1Bytes;
}
- (BOOL)stretchEncryptionKey {
    return stretchEncryptionKey;
}
- (BOOL)compressed {
    return compressed;
}
- (BOOL)isEqualToBlobKey:(BlobKey *)other {
    if (memcmp(sha1Bytes, [other sha1Bytes], 20) != 0) {
        return NO;
    }
    if (stretchEncryptionKey != [other stretchEncryptionKey]) {
        return NO;
    }
    return YES;
}


#pragma mark NSCopying
- (id)copyWithZone:(NSZone *)zone {
    return [[BlobKey alloc] initWithStorageType:storageType archiveId:archiveId archiveSize:archiveSize archiveUploadedDate:archiveUploadedDate sha1Bytes:sha1Bytes stretchEncryptionKey:stretchEncryptionKey compressed:compressed];
}


#pragma mark NSObject
- (NSString *)description {
    if (storageType == StorageTypeS3 || storageType == StorageTypeS3Glacier) {
        NSString *type = storageType == StorageTypeS3 ? @"S3" : @"S3Glacier";
        return [NSString stringWithFormat:@"<BlobKey sha1=%@,type=%@,stretchedkey=%@,compressed=%@>", [self sha1], type, (stretchEncryptionKey ? @"YES" : @"NO"), (compressed ? @"YES" : @"NO")];
    }
    return [NSString stringWithFormat:@"<BlobKey sha1=%@,type=Glacier,archiveId=%@,archiveSize=%qu,archiveUploadedDate=%@,stretchedkey=%@,compressed=%@>", [self sha1], archiveId, archiveSize, [self archiveUploadedDate], (stretchEncryptionKey ? @"YES" : @"NO"), (compressed ? @"YES" : @"NO")];
}
- (BOOL)isEqual:(id)anObject {
    if (![anObject isKindOfClass:[BlobKey class]]) {
        return NO;
    }
    BlobKey *other = (BlobKey *)anObject;
    
    return memcmp(sha1Bytes, [other sha1Bytes], 20) == 0
    && stretchEncryptionKey == [other stretchEncryptionKey]
    && storageType == [other storageType]
    && [NSObject equalObjects:archiveId and:[other archiveId]]
    && archiveSize == [other archiveSize]
    && [NSObject equalObjects:archiveUploadedDate and:[other archiveUploadedDate]]
    && compressed == [other compressed];
}
- (NSUInteger)hash {
    return (NSUInteger)(*sha1Bytes);
}


#pragma mark internal
- (id)initWithStorageType:(StorageType)theStorageType archiveId:(NSString *)theArchiveId archiveSize:(uint64_t)theArchiveSize archiveUploadedDate:(NSDate *)theArchiveUploadedDate sha1Bytes:(unsigned char *)theSHA1Bytes stretchEncryptionKey:(BOOL)isStretchedKey compressed:(BOOL)isCompressed {
    if (self = [super init]) {
        storageType = theStorageType;
        archiveId = [theArchiveId retain];
        archiveSize = theArchiveSize;
        archiveUploadedDate = [theArchiveUploadedDate retain];
        
        NSAssert(theSHA1Bytes != NULL, @"theSHA1Bytes may not be null");
        sha1Bytes = (unsigned char *)malloc(20);
        memcpy(sha1Bytes, theSHA1Bytes, 20);
        
        stretchEncryptionKey = isStretchedKey;
        compressed = isCompressed;
    }
    return self;
}
@end
