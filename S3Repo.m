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

#import "ServerBlob.h"
#import "S3Repo.h"
#import "S3Service.h"
#import "S3Fark.h"
#import "SetNSError.h"
#import "Tree.h"
#import "Commit.h"
#import "NSData-Encrypt.h"
#import "DecryptedInputStream.h"
#import "InputStreams.h"
#import "NSErrorCodes.h"
#import "NSData-InputStream.h"
#import "DataInputStream.h"
#import "HTTP.h"

@interface S3Repo (internal)
- (NSData *)dataForSHA1:(NSString *)sha1 packSetName:(NSString *)thePackSetName error:(NSError **)error;
- (NSData *)dataForSHA1:(NSString *)sha1 packSetName:(NSString *)thePackSetName searchPackOnly:(BOOL)packOnly error:(NSError **)error;
- (BOOL)ancestorCommitSHA1sForCommitSHA1:(NSString *)commitSHA1 outArray:(NSMutableArray *)arr error:(NSError **)error;
- (BOOL)commitSHA1:(NSString **)sha1 fromSHA1:(NSString *)fromSHA1 before:(NSDate *)date error:(NSError **)error;
@end

static NSString *ERROR_DOMAIN = @"S3RepoErrorDomain";

@implementation S3Repo
+ (NSString *)errorDomain {
    return ERROR_DOMAIN;
}
- (id)initWithS3Service:(S3Service *)theS3
           s3BucketName:(NSString *)theS3BucketName
           computerUUID:(NSString *)theComputerUUID
             bucketUUID:(NSString *)theBucketUUID
              encrypted:(BOOL)isEncrypted
          encryptionKey:(NSString *)theEncryptionKey
                   fark:(S3Fark *)theFark 
   ensureCacheIntegrity:(BOOL)ensure {
    if (self = [super init]) {
        s3 = [theS3 retain];
        s3BucketName = [theS3BucketName copy];
        computerUUID = [theComputerUUID copy];
        bucketUUID = [theBucketUUID copy];
        encrypted = isEncrypted;
        encryptionKey = [theEncryptionKey copy];
        fark = [theFark retain];
        ensureCacheIntegrity = ensure;
        treesPackSetName = [[NSString alloc] initWithFormat:@"%@-trees", bucketUUID];
        blobsPackSetName = [[NSString alloc] initWithFormat:@"%@-blobs", bucketUUID];
    }
    return self;
}
- (void)dealloc {
    [s3 release];
    [s3BucketName release];
    [computerUUID release];
    [bucketUUID release];
    [encryptionKey release];
    [fark release];
    [treesPackSetName release];
    [blobsPackSetName release];
    [super dealloc];
}
- (BOOL)localHeadSHA1:(NSString **)headSHA1 error:(NSError **)error {
    *headSHA1 = nil;
    NSError *myError;
    NSData *headSHA1Data = [s3 dataAtPath:[self localHeadS3Path] error:&myError];
    if (headSHA1Data == nil && !([[myError domain] isEqualToString:[S3Service serverErrorDomain]] && [myError code] == HTTP_NOT_FOUND)) {
        if (error != NULL) {
            *error = myError;
        }
        return NO;
    }
    if (headSHA1Data != nil) {
        *headSHA1 = [[[NSString alloc] initWithData:headSHA1Data encoding:NSUTF8StringEncoding] autorelease];
    }
    return YES;
}
- (BOOL)commit:(Commit **)commit forSHA1:(NSString *)theSHA1 error:(NSError **)error {
    *commit = nil;
    NSData *data = [self dataForSHA1:theSHA1 packSetName:treesPackSetName searchPackOnly:YES error:error];
    if (data == nil) {
        HSLogDebug(@"commit data not found for %@", theSHA1);
        return NO;
    }
    id <BufferedInputStream> is = [data newInputStream];
    *commit = [[[Commit alloc] initWithBufferedInputStream:is error:error] autorelease];
    [is release];
    if (*commit == nil) {
        return NO;
    }
    return YES;
}
- (BOOL)tree:(Tree **)tree forSHA1:(NSString *)theSHA1 error:(NSError **)error {
    *tree = nil;
    NSData *data = [self dataForSHA1:theSHA1 packSetName:treesPackSetName searchPackOnly:YES error:error];
    if (data == nil) {
        HSLogDebug(@"tree data not found for %@", theSHA1);
        return NO;
    }
    id <BufferedInputStream> is = [data newInputStream];
    *tree = [[[Tree alloc] initWithBufferedInputStream:is error:error] autorelease];
    [is release];
    if (*tree == nil) {
        return NO;
    }
    return YES;
}
- (BOOL)containsBlobForSHA1:(NSString *)sha1 packSetName:(NSString *)packSetName searchPackOnly:(BOOL)searchPackOnly {
    return [fark containsBlobForSHA1:sha1 packSetName:packSetName searchPackOnly:searchPackOnly];
}
- (NSData *)dataForSHA1:(NSString *)sha1 error:(NSError **)error {
    NSData *data = [fark dataForSHA1:sha1 packSetName:treesPackSetName searchPackOnly:YES error:error];
    if (data == nil) {
        data = [fark dataForSHA1:sha1 packSetName:blobsPackSetName searchPackOnly:NO error:error];
    }
    if (data != nil && encrypted) {
        data = [data decryptWithCipher:ARQ_DEFAULT_CIPHER_NAME key:encryptionKey error:error];
    }
    return data;
}
- (ServerBlob *)newServerBlobForSHA1:(NSString *)sha1 error:(NSError **)error {
    ServerBlob *sb = [fark newServerBlobForSHA1:sha1 packSetName:treesPackSetName searchPackOnly:NO error:error];
    if (sb == nil) {
        sb = [fark newServerBlobForSHA1:sha1 packSetName:blobsPackSetName searchPackOnly:NO error:error];
    }
    if (sb != nil && encrypted) {
        id <InputStream> is = [sb newInputStream];
        NSString *mimeType = [sb mimeType];
        NSString *downloadName = [sb downloadName];
        [sb release];
        DecryptedInputStream *dis = [[DecryptedInputStream alloc] initWithInputStream:is cipherName:ARQ_DEFAULT_CIPHER_NAME key:encryptionKey error:error];
        [is release];
        if (dis == nil) {
            return NO;
        }
        sb = [[ServerBlob alloc] initWithInputStream:dis mimeType:mimeType downloadName:downloadName];
        [dis release];
    }
    return sb;
}
- (NSData *)dataForSHA1s:(NSArray *)sha1s error:(NSError **)error {
    NSMutableData *data = [NSMutableData data];
    for (NSString *sha1 in sha1s) {
        ServerBlob *sb = [self newServerBlobForSHA1:sha1 error:error];
        if (sb == nil) {
            return NO;
        }
        NSData *blobData = [sb slurp:error];
        [sb release];
        if (blobData == nil) {
            return NO;
        }
        //FIXME: Get rid of this extra copying of data.
        [data appendData:blobData];
    }
    return data;
}
- (BOOL)commonAncestorCommitSHA1:(NSString **)ancestorSHA1 forCommitSHA1:(NSString *)commit0SHA1 andCommitSHA1:(NSString *)commit1SHA1 error:(NSError **)error {
	//FIXME: This is slow and memory-intensive!
	NSMutableArray *commit0ParentSHA1s = [[[NSMutableArray alloc] initWithObjects:commit0SHA1, nil] autorelease];
	NSMutableArray *commit1ParentSHA1s = [[[NSMutableArray alloc] initWithObjects:commit1SHA1, nil] autorelease];
	if (![self ancestorCommitSHA1sForCommitSHA1:commit0SHA1 outArray:commit0ParentSHA1s error:error]) {
        return NO;
    }
	if (![self ancestorCommitSHA1sForCommitSHA1:commit1SHA1 outArray:commit1ParentSHA1s error:error]) {
        return NO;
    }
	for (NSString *parent in commit1ParentSHA1s) {
		if ([commit0ParentSHA1s containsObject:parent]) {
            *ancestorSHA1 = parent;
			break;
		}
	}
    return YES;
}
- (BOOL)is:(BOOL *)isAncestor commitSHA1:(NSString *)ancestorCommitSHA1 ancestorOfCommitSHA1:(NSString *)sha1 error:(NSError **)error {
    *isAncestor = NO;
    if ([ancestorCommitSHA1 isEqualToString:sha1]) {
        return YES;
    }
    //TODO: Get rid of recursion in this method:
    Commit *commit = nil;
    if (![self commit:&commit forSHA1:sha1 error:error]) {
        return NO;
    }
    for (NSString *parentCommitSHA1 in [commit parentCommitSHA1s]) {
        if (![self is:isAncestor commitSHA1:parentCommitSHA1 ancestorOfCommitSHA1:ancestorCommitSHA1 error:error]) {
            return NO;
        }
        if (*isAncestor) {
            return YES;
        }
    }
    return YES;
}
- (NSString *)localHeadS3Path {
    return [NSString stringWithFormat:@"/%@/%@/bucketdata/%@/refs/heads/master", s3BucketName, computerUUID, bucketUUID];
}
- (BOOL)isEncrypted {
    return encrypted;
}
- (NSString *)blobsPackSetName {
    return blobsPackSetName;
}
- (NSSet *)packSetNames {
    return [NSSet setWithObjects:blobsPackSetName, treesPackSetName, nil];
}

#pragma mark NSObject protocol
- (NSString *)description {
    return [NSString stringWithFormat:@"<S3Repo %p bucket %@>", self, bucketUUID];
}
@end

@implementation S3Repo (internal)
- (NSData *)dataForSHA1:(NSString *)sha1 packSetName:(NSString *)thePackSetName error:(NSError **)error {
    return [self dataForSHA1:sha1 packSetName:thePackSetName searchPackOnly:NO error:error];
}
- (NSData *)dataForSHA1:(NSString *)sha1 packSetName:(NSString *)thePackSetName searchPackOnly:(BOOL)packOnly error:(NSError **)error {
    NSData *data = [fark dataForSHA1:sha1 packSetName:thePackSetName searchPackOnly:packOnly error:error];
    if (data != nil && encrypted) {
        data = [data decryptWithCipher:ARQ_DEFAULT_CIPHER_NAME key:encryptionKey error:error];
    }
    return data;
}
- (BOOL)ancestorCommitSHA1sForCommitSHA1:(NSString *)commitSHA1 outArray:(NSMutableArray *)arr error:(NSError **)error {
	Commit *commit = nil;
    if (![self commit:&commit forSHA1:commitSHA1 error:error]) {
        return NO;
    }
	for (NSString *parentCommitSHA1 in [commit parentCommitSHA1s]) {
		[arr addObject:parentCommitSHA1];
		if (![self ancestorCommitSHA1sForCommitSHA1:parentCommitSHA1 outArray:arr error:error]) {
            return NO;
        }
	}
    return YES;
}
- (BOOL)commitSHA1:(NSString **)sha1 fromSHA1:(NSString *)fromSHA1 before:(NSDate *)date error:(NSError **)error {
    HSLogDebug(@"looking for Commit before %@", [date description]);
    *sha1 = nil;
    for (;;) {
        Commit *commit = nil;
        if (![self commit:&commit forSHA1:fromSHA1 error:error]) {
            return NO;
        }
        NSDate *creationDate = [commit creationDate];
        if ([date earlierDate:creationDate] == creationDate) {
            *sha1 = [[fromSHA1 retain] autorelease];
            HSLogDebug(@"returning Commit SHA1 %@: creationDate=%@", *sha1, creationDate);
            break;
        }
        if ([[commit parentCommitSHA1s] count] == 0) {
            break;
        }
        fromSHA1 = [[[commit parentCommitSHA1s] allObjects] objectAtIndex:0];
    }
    return YES;
}
@end
