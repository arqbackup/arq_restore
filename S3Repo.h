/*
 Copyright (c) 2009, Stefan Reitshamer http://www.haystacksoftware.com
 
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

#import <Cocoa/Cocoa.h>
@class S3Service;
@class S3Fark;
@class Commit;
@class Tree;
@class Blob;
@class ServerBlob;


@interface S3Repo : NSObject {
    S3Service *s3;
	NSString *s3BucketName;
    NSString *computerUUID;
	NSString *bucketUUID;
    S3Fark *fark;
    BOOL encrypted;
    NSString *encryptionKey;
    BOOL ensureCacheIntegrity;
    NSString *treesPackSetName;
    NSString *blobsPackSetName;
}
+ (NSString *)errorDomain;

- (id)initWithS3Service:(S3Service *)theS3
           s3BucketName:(NSString *)theS3BucketName
           computerUUID:(NSString *)theComputerUUID
             bucketUUID:(NSString *)theBucketUUID
              encrypted:(BOOL)isEncrypted
          encryptionKey:(NSString *)theEncryptionKey
                   fark:(S3Fark *)theFark 
   ensureCacheIntegrity:(BOOL)ensure;

- (BOOL)localHeadSHA1:(NSString **)localHeadSHA1 error:(NSError **)error;

// Returns NO if commit not found:
- (BOOL)commit:(Commit **)commit forSHA1:(NSString *)theSHA1 error:(NSError **)error;

// Returns NO if commit not found:
- (BOOL)tree:(Tree **)tree forSHA1:(NSString *)theSHA1 error:(NSError **)error;

- (BOOL)containsBlobForSHA1:(NSString *)sha1 packSetName:(NSString *)packSetName searchPackOnly:(BOOL)searchPackOnly;
- (NSString *)packSHA1ForPackedBlobSHA1:(NSString *)sha1 packSetName:(NSString *)packSetName;
- (NSData *)dataForSHA1:(NSString *)sha1 error:(NSError **)error;
- (ServerBlob *)newServerBlobForSHA1:(NSString *)sha1 error:(NSError **)error;
- (NSData *)dataForSHA1s:(NSArray *)sha1s error:(NSError **)error;
- (BOOL)commonAncestorCommitSHA1:(NSString **)ancestorSHA1 forCommitSHA1:(NSString *)commit0SHA1 andCommitSHA1:(NSString *)commit1SHA1 error:(NSError **)error;
- (BOOL)is:(BOOL *)isAncestor commitSHA1:(NSString *)descendantSHA1 ancestorOfCommitSHA1:(NSString *)sha1 error:(NSError **)error;
- (NSString *)localHeadS3Path;
- (BOOL)isEncrypted;
- (NSString *)blobsPackSetName;
- (NSSet *)packSetNames;
@end
