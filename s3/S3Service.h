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
#import "S3Receiver.h"
@class Blob;
@class S3AuthorizationProvider;
@class ServerBlob;

enum {
    BUCKET_REGION_US_STANDARD = 0,
    BUCKET_REGION_US_WEST = 1,
    BUCKET_REGION_EU = 2,
    BUCKET_REGION_AP_SOUTHEAST_1 = 3
};

@interface S3Service : NSObject {
	S3AuthorizationProvider *sap;
    BOOL useSSL;
    BOOL retryOnNetworkError;
}
+ (NSString *)errorDomain;
+ (NSString *)serverErrorDomain;
+ (NSString *)displayNameForBucketRegion:(int)region;
+ (NSString *)s3BucketNameForAccessKeyID:(NSString *)theAccessKeyId region:(int)s3BucketRegion;
+ (NSArray *)s3BucketNamesForAccessKeyID:(NSString *)theAccessKeyId;
- (id)initWithS3AuthorizationProvider:(S3AuthorizationProvider *)theSAP useSSL:(BOOL)useSSL retryOnNetworkError:(BOOL)retry;
- (NSArray *)s3BucketNames:(NSError **)error;
- (BOOL)s3BucketExists:(NSString *)s3BucketName;

- (NSArray *)pathsWithPrefix:(NSString *)prefix error:(NSError **)error;
- (NSArray *)objectsWithPrefix:(NSString *)prefix error:(NSError **)error;
- (BOOL)listObjectsWithPrefix:(NSString *)prefix receiver:(id <S3Receiver>)receiver error:(NSError **)error;
- (BOOL)listObjectsWithMax:(int)maxResults prefix:(NSString *)prefix receiver:(id <S3Receiver>)receiver error:(NSError **)error;
- (BOOL)containsBlobAtPath:(NSString *)path;

- (NSData *)dataAtPath:(NSString *)path error:(NSError **)error;
- (ServerBlob *)newServerBlobAtPath:(NSString *)path error:(NSError **)error;


- (NSArray *)commonPrefixesForPathPrefix:(NSString *)prefix delimiter:(NSString *)delimiter error:(NSError **)error;

@end
