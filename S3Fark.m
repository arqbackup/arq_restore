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

#import "S3Service.h"
#import "S3Fark.h"
#import "SetNSError.h"
#import "NSErrorCodes.h"
#import "PackSetSet.h"
#import "ServerBlob.h"

@interface S3Fark (internal)
- (NSString *)pathForSHA1:(NSString *)sha1;
@end

@implementation S3Fark
- (id)initWithS3Service:(S3Service *)theS3
           s3BucketName:(NSString *)theS3BucketName
           computerUUID:(NSString *)theComputerUUID {
	if (self = [super init]) {
        s3 = [theS3 retain];
        s3BucketName = [theS3BucketName copy];
        computerUUID = [theComputerUUID copy];
        creatorThread = [[NSThread currentThread] retain];
        packSetSet = [[PackSetSet alloc] initWithS3Service:s3 s3BucketName:s3BucketName computerUUID:computerUUID];
	}
	return self;
}
- (void)dealloc {
    [s3 release];
    [s3BucketName release];
    [computerUUID release];
    [creatorThread release];
    [packSetSet release];
	[super dealloc];
}
- (NSData *)dataForSHA1:(NSString *)sha1 packSetName:(NSString *)packSetName searchPackOnly:(BOOL)searchPackOnly error:(NSError **)error {
    ServerBlob *sb = [self newServerBlobForSHA1:sha1 packSetName:packSetName searchPackOnly:searchPackOnly error:error];
    if (sb == nil) {
        return nil;
    }
    NSData *data = [sb slurp:error];
    [sb release];
    return data;
}
- (ServerBlob *)newServerBlobForSHA1:(NSString *)sha1 packSetName:(NSString *)packSetName searchPackOnly:(BOOL)searchPackOnly error:(NSError **)error {
    NSAssert([NSThread currentThread] == creatorThread, @"must be on same thread!");
    NSError *myError = nil;
    ServerBlob *sb = [packSetSet newServerBlobForSHA1:sha1 packSetName:packSetName error:&myError];
    if (sb == nil) {
        if ([myError code] != ERROR_NOT_FOUND) {
            HSLogError(@"error reading sha1 %@ from packSetSet: %@", sha1, [myError localizedDescription]);
        }
        if (error != NULL) {
            *error = myError;
        }
        if (!searchPackOnly) {
            sb = [s3 newServerBlobAtPath:[self pathForSHA1:sha1] error:error];
        }
    }
    return sb;
}
- (BOOL)containsBlobForSHA1:(NSString *)sha1 packSetName:(NSString *)packSetName searchPackOnly:(BOOL)searchPackOnly {
    NSAssert([NSThread currentThread] == creatorThread, @"must be on same thread!");
    BOOL contains = [packSetSet containsBlobForSHA1:sha1 packSetName:packSetName];
    if (!contains && !searchPackOnly) {
        contains = [s3 containsBlobAtPath:[self pathForSHA1:sha1]];
    }
    return contains;
}
- (NSString *)packSHA1ForPackedBlobSHA1:(NSString *)sha1 packSetName:(NSString *)packSetName {
	return [packSetSet packSHA1ForPackedBlobSHA1:sha1 packSetName:packSetName];
}
- (BOOL)reloadPacksFromS3:(NSError **)error {
    NSAssert([NSThread currentThread] == creatorThread, @"must be on same thread!");
    return [packSetSet resetFromS3:error];
}
@end

@implementation S3Fark (internal)
- (NSString *)pathForSHA1:(NSString *)sha1 {
    return [NSString stringWithFormat:@"/%@/%@/objects/%@", s3BucketName, computerUUID, sha1];
}
@end
