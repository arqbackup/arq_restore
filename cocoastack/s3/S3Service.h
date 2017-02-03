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



#import "ItemFS.h"
#import "S3Receiver.h"
#import "InputStream.h"
@protocol S3AuthorizationProvider;
@class S3Owner;
@protocol DataTransferDelegate;
@protocol TargetConnectionDelegate;
@class Item;
@class LifecycleConfiguration;


#define S3_INITIAL_RETRY_SLEEP (0.5)
#define S3_RETRY_SLEEP_GROWTH_FACTOR (1.5)
#define S3_MAX_RETRY (5)

extern NSString *kS3StorageClassStandard;
extern NSString *kS3StorageClassReducedRedundancy;


enum {
    S3SERVICE_ERROR_UNEXPECTED_RESPONSE = -51001,
    S3SERVICE_ERROR_AMAZON_ERROR = -51002,
    S3SERVICE_INVALID_PARAMETERS = -51003
};

enum {
    GLACIER_RETRIEVAL_TIER_BULK = 0,
    GLACIER_RETRIEVAL_TIER_STANDARD = 1,
    GLACIER_RETRIEVAL_TIER_EXPEDITED = 2
};

@interface S3Service : NSObject <ItemFS, NSCopying> {
    id <S3AuthorizationProvider> sap;
    NSURL *endpoint;
}
+ (NSString *)errorDomain;

- (id)initWithS3AuthorizationProvider:(id <S3AuthorizationProvider>)theSAP endpoint:(NSURL *)theEndpoint;

- (S3Owner *)s3OwnerWithTargetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD error:(NSError **)error;
- (NSArray *)s3BucketNamesWithTargetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD error:(NSError **)error;
- (NSNumber *)s3BucketExists:(NSString *)s3BucketName targetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD error:(NSError **)error;
- (NSString *)locationOfS3Bucket:(NSString *)theS3BucketName targetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD error:(NSError **)error;
@end
