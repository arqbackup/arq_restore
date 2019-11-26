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
@class BufferedInputStream;


typedef enum {
    BlobKeyCompressionNone = 0,
    BlobKeyCompressionGzip = 1,
    BlobKeyCompressionLZ4 = 2
} BlobKeyCompressionType;


@interface BlobKey : NSObject <NSCopying> {
    StorageType storageType;
    NSString *archiveId;
    uint64_t archiveSize;
    NSDate *archiveUploadedDate;
    unsigned char *sha1Bytes;
    BOOL stretchEncryptionKey;
    BlobKeyCompressionType compressionType;
}

- (id)initWithSHA1:(NSString *)theSHA1 archiveId:(NSString *)theArchiveId archiveSize:(uint64_t)theArchiveSize archiveUploadedDate:(NSDate *)theArchiveUploadedDate compressionType:(BlobKeyCompressionType)theCompressionType error:(NSError **)error;
- (id)initWithSHA1:(NSString *)theSHA1 storageType:(StorageType)theStorageType stretchEncryptionKey:(BOOL)isStretchedKey compressionType:(BlobKeyCompressionType)theCompressionType error:(NSError **)error;
- (id)initWithStorageType:(StorageType)theStorageType archiveId:(NSString *)theArchiveId archiveSize:(uint64_t)theArchiveSize archiveUploadedDate:(NSDate *)theArchiveUploadedDate sha1:(NSString *)theSHA1 stretchEncryptionKey:(BOOL)isStretchedKey compressionType:(BlobKeyCompressionType)theCompressionType error:(NSError **)error;
- (id)initCopyOfBlobKey:(BlobKey *)theBlobKey withStorageType:(StorageType)theStorageType;

- (StorageType)storageType;
- (NSString *)archiveId;
- (uint64_t)archiveSize;
- (NSDate *)archiveUploadedDate;
- (NSString *)sha1;
- (unsigned char *)sha1Bytes;
- (BOOL)stretchEncryptionKey;
- (BlobKeyCompressionType)compressionType;
- (BOOL)isEqualToBlobKey:(BlobKey *)other;
@end
