/*
 Copyright (c) 2009-2011, Stefan Reitshamer http://www.haystacksoftware.com
 
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
#import "Blob.h"
#import "InputStream.h"
@class S3AuthorizationProvider;
@class S3Owner;
@class ServerBlob;

#define S3_INITIAL_RETRY_SLEEP (0.5)
#define S3_RETRY_SLEEP_GROWTH_FACTOR (1.5)
#define S3_MAX_RETRY (5)

enum {
    S3SERVICE_ERROR_UNEXPECTED_RESPONSE = -51001,
    S3SERVICE_ERROR_AMAZON_ERROR = -51002,
    S3SERVICE_INVALID_PARAMETERS = -51003
};

@interface S3Service : NSObject <NSCopying> {
	S3AuthorizationProvider *sap;
    BOOL useSSL;
    BOOL retryOnTransientError;
}
+ (NSString *)errorDomain;
- (id)initWithS3AuthorizationProvider:(S3AuthorizationProvider *)theSAP useSSL:(BOOL)useSSL retryOnTransientError:(BOOL)retry;
- (S3Owner *)s3Owner:(NSError **)error;
- (NSArray *)s3BucketNames:(NSError **)error;
- (BOOL)s3BucketExists:(NSString *)s3BucketName;

- (NSArray *)pathsWithPrefix:(NSString *)prefix error:(NSError **)error;
- (NSArray *)pathsWithPrefix:(NSString *)prefix delimiter:(NSString *)delimiter error:(NSError **)error;
- (NSArray *)commonPrefixesForPathPrefix:(NSString *)prefix delimiter:(NSString *)delimiter error:(NSError **)error;
- (NSArray *)objectsWithPrefix:(NSString *)prefix error:(NSError **)error;
- (BOOL)listObjectsWithPrefix:(NSString *)prefix receiver:(id <S3Receiver>)receiver error:(NSError **)error;
- (BOOL)containsBlob:(BOOL *)contains atPath:(NSString *)path dataSize:(unsigned long long *)dataSize error:(NSError **)error;

- (NSData *)dataAtPath:(NSString *)path error:(NSError **)error;
- (ServerBlob *)newServerBlobAtPath:(NSString *)path error:(NSError **)error;

- (BOOL)aclXMLData:(NSData **)aclXMLData atPath:(NSString *)path error:(NSError **)error;
- (BOOL)acl:(int *)acl atPath:(NSString *)path error:(NSError **)error;

- (S3AuthorizationProvider *)s3AuthorizationProvider;
@end
