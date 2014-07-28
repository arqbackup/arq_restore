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



#import "S3Receiver.h"
#import "InputStream.h"
@class S3AuthorizationProvider;
@class S3Owner;
@protocol DataTransferDelegate;
@protocol TargetConnectionDelegate;


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

@interface S3Service : NSObject <NSCopying> {
	S3AuthorizationProvider *sap;
    NSURL *endpoint;
    BOOL useAmazonRRS;
}
+ (NSString *)errorDomain;

- (id)initWithS3AuthorizationProvider:(S3AuthorizationProvider *)theSAP endpoint:(NSURL *)theEndpoint useAmazonRRS:(BOOL)isUseAmazonRRS;

- (S3Owner *)s3OwnerWithTargetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD error:(NSError **)error;
- (NSArray *)s3BucketNamesWithTargetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD error:(NSError **)error;
- (NSNumber *)s3BucketExists:(NSString *)s3BucketName targetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD error:(NSError **)error;
- (NSString *)locationOfS3Bucket:(NSString *)theS3BucketName targetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD error:(NSError **)error;

- (NSArray *)pathsWithPrefix:(NSString *)prefix targetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD error:(NSError **)error;
- (NSArray *)pathsWithPrefix:(NSString *)prefix delimiter:(NSString *)delimiter targetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD error:(NSError **)error;
- (NSArray *)commonPrefixesForPathPrefix:(NSString *)prefix delimiter:(NSString *)delimiter targetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD error:(NSError **)error;
- (NSArray *)objectsWithPrefix:(NSString *)prefix targetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD error:(NSError **)error;
- (BOOL)listObjectsWithPrefix:(NSString *)prefix receiver:(id <S3Receiver>)receiver targetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD error:(NSError **)error;
- (NSNumber *)containsObjectAtPath:(NSString *)path dataSize:(unsigned long long *)dataSize targetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD error:(NSError **)error;
- (NSNumber *)isObjectRestoredAtPath:(NSString *)thePath targetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD error:(NSError **)error;
- (BOOL)restoreObjectAtPath:(NSString *)thePath forDays:(NSUInteger)theDays alreadyRestoredOrRestoring:(BOOL *)alreadyRestoredOrRestoring targetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD error:(NSError **)error;

- (NSData *)dataAtPath:(NSString *)path targetConnectionDelegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error;
- (NSData *)dataAtPath:(NSString *)path dataTransferDelegate:(id <DataTransferDelegate>)theDelegate targetConnectionDelegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error;

- (S3AuthorizationProvider *)s3AuthorizationProvider;

- (BOOL)createS3Bucket:(NSString *)s3BucketName withLocationConstraint:(NSString *)theLocationConstraint targetConnectionDelegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error;
- (BOOL)deleteS3Bucket:(NSString *)s3BucketName targetConnectionDelegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error;
- (BOOL)putData:(NSData *)theData atPath:(NSString *)path targetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD error:(NSError **)error;
- (BOOL)putData:(NSData *)theData atPath:(NSString *)path dataTransferDelegate:(id <DataTransferDelegate>)theDTD targetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD error:(NSError **)error;
- (BOOL)deletePaths:(NSArray *)thePaths targetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD error:(NSError **)error;
- (BOOL)deletePath:(NSString *)path targetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD error:(NSError **)error;
- (BOOL)setStorageClass:(NSString *)storageClass forPath:(NSString *)path targetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD error:(NSError **)error;
- (NSString *)storageClass;
- (BOOL)copy:(NSString *)sourcePath to:(NSString *)destPath targetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD error:(NSError **)error;

- (NSNumber *)containsLifecyclePolicyWithId:(NSString *)theId forS3BucketName:(NSString *)theS3BucketName targetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD error:(NSError **)error;
- (BOOL)putGlacierLifecyclePolicyWithId:(NSString *)theId forPrefixes:(NSArray *)thePrefixes s3BucketName:(NSString *)theS3BucketName transitionDays:(NSUInteger)theTransitionDays targetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD error:(NSError **)error;
@end
