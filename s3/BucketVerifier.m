/*
 Copyright (c) 2009-2010, Stefan Reitshamer http://www.haystacksoftware.com
 
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

#import "BucketVerifier.h"
#import "S3Service.h"
#import "ArqFark.h"
#import "ArqRepo.h"
#import "ArqRepo_Verifier.h"
#import "Commit.h"
#import "Tree.h"
#import "Node.h"
#import "SetNSError.h"
#import "NSError_extra.h"
#import "NSErrorCodes.h"

@interface BucketVerifier (internal)
- (BOOL)verifyTree:(NSString *)treeSHA1 path:(NSString *)path error:(NSError **)error;
- (BOOL)verify:(NSString *)sha1 error:(NSError **)error;
@end

@implementation BucketVerifier
- (id)initWithS3Service:(S3Service *)theS3 s3BucketName:(NSString *)theS3BucketName computerUUID:(NSString *)theComputerUUID bucketUUID:(NSString *)theBucketUUID s3ObjectSHA1s:(NSArray *)theObjectSHA1s encryptionKey:(NSString *)encryptionKey {
	if (self = [super init]) {
		s3 = [theS3 retain];
		s3BucketName = [theS3BucketName retain];
		computerUUID = [theComputerUUID retain];
		bucketUUID = [theBucketUUID retain];
		objectSHA1s = [theObjectSHA1s retain];
		fark = [[ArqFark alloc] initWithS3Service:s3 s3BucketName:s3BucketName computerUUID:computerUUID];
		repo = [[ArqRepo alloc] initWithS3Service:s3 s3BucketName:s3BucketName computerUUID:computerUUID bucketUUID:bucketUUID encryptionKey:encryptionKey];
	}
	return self;
}
- (void)dealloc {
	[s3 release];
	[s3BucketName release];
	[computerUUID release];
	[bucketUUID release];
	[objectSHA1s release];
	[fark release];
	[repo release];
	[super dealloc];
}	
- (BOOL)verify:(NSError **)error {
    printf("verifying all objects exist for commits in %s\n", [bucketUUID UTF8String]);
	
    NSError *myError = nil;
	NSString *headSHA1 = [repo headSHA1:&myError];
    if (headSHA1 == nil) {
        if ([myError isErrorWithDomain:[ArqRepo errorDomain] code:ERROR_NOT_FOUND]) {
            printf("no head commit for s3Bucket %s computerUUID %s bucketUUID %s is %s\n", [s3BucketName UTF8String], [computerUUID UTF8String], [bucketUUID UTF8String], [headSHA1 UTF8String]);
        } else {
            if (error != NULL) {
                *error = myError;
            }
            return NO;
        }
	} else {
        printf("head commit for s3Bucket %s computerUUID %s bucketUUID %s is %s\n", [s3BucketName UTF8String], [computerUUID UTF8String], [bucketUUID UTF8String], [headSHA1 UTF8String]);
        NSString *commitSHA1 = headSHA1;
        while (commitSHA1 != nil) {
            printf("verifying commit %s bucketUUID %s\n", [commitSHA1 UTF8String], [bucketUUID UTF8String]);
            Commit *commit = [repo commitForSHA1:commitSHA1 error:error];
            if (commit == nil) {
                return NO;
            }
            printf("commit %s's tree is %s\n", [commitSHA1 UTF8String], [[commit treeSHA1] UTF8String]);
            if (![self verifyTree:[commit treeSHA1] path:@"/" error:error]) {
                return NO;
            }
            commitSHA1 = [[commit parentCommitSHA1s] anyObject];
        }
    }
	return YES;
}
@end

@implementation BucketVerifier (internal)
- (BOOL)verifyTree:(NSString *)treeSHA1 path:(NSString *)path error:(NSError **)error {
	printf("verifying tree %s (path %s)\n", [treeSHA1 UTF8String], [path UTF8String]);
	Tree *tree = [repo treeForSHA1:treeSHA1 error:error];
    if (tree == nil) {
		fprintf(stderr, "tree %s not found\n", [treeSHA1 UTF8String]);
		return NO;
	}
	if ([tree xattrsSHA1] != nil) {
		printf("verifying xattrsSHA1 for tree %s\n", [treeSHA1 UTF8String]);
		if (![self verify:[tree xattrsSHA1] error:error]) {
			fprintf(stderr, "tree %s's xattrsSHA1 %s not found", [treeSHA1 UTF8String], [[tree xattrsSHA1] UTF8String]);
			return NO;
		}
	}
	if ([tree aclSHA1] != nil) {
		printf("verifying aclSHA1 for tree %s\n", [treeSHA1 UTF8String]);
		if (![self verify:[tree aclSHA1] error:error]) {
			fprintf(stderr, "tree %s's aclSHA1 %s not found", [treeSHA1 UTF8String], [[tree aclSHA1] UTF8String]);
			return NO;
		}
	}
    for (NSString *childNodeName in [tree childNodeNames]) {
        Node *node = [tree childNodeWithName:childNodeName];
        NSArray *dataSHA1s = [node dataSHA1s];
		NSString *childPath = [path stringByAppendingPathComponent:childNodeName];
        if ([node isTree]) {
            NSAssert([dataSHA1s count] == 1, ([NSString stringWithFormat:@"tree %@ node %@ must have exactly 1 dataSHA1", treeSHA1, childNodeName]));
            if (![self verifyTree:[dataSHA1s objectAtIndex:0] path:childPath error:error]) {
                return NO;
            }
        } else {
			printf("verifying data sha1s for node %s\n", [childPath UTF8String]);
            for (NSString *dataSHA1 in dataSHA1s) {
                if (![self verify:dataSHA1 error:error]) {
                    HSLogError(@"missing data sha1 %@ for node %@ in tree %@", dataSHA1, childNodeName, treeSHA1);
                    return NO;
                }
            }
			if ([node thumbnailSHA1] != nil) {
				printf("verifying thumbnailSHA1 for node %s\n", [childPath UTF8String]);
				if (![self verify:[node thumbnailSHA1] error:error]) {
					HSLogError(@"missing thumbnail sha1 %@ for node %@ in tree %@", [node thumbnailSHA1], childNodeName, treeSHA1);
					return NO;
				}
			}
			if ([node previewSHA1] != nil) {
				printf("verifying previewSHA1 for node %s\n", [childPath UTF8String]);
				if (![self verify:[node previewSHA1] error:error]) {
					HSLogError(@"missing preview sha1 %@ for node %@ in tree %@", [node previewSHA1], childNodeName, treeSHA1);
					return NO;
				}
			}
			if ([node xattrsSHA1] != nil) {
				printf("verifying xattrsSHA1 for node %s\n", [childPath UTF8String]);
				if (![self verify:[node xattrsSHA1] error:error]) {
					HSLogError(@"missing xattrs sha1 %@ for node %@ in tree %@", [node xattrsSHA1], childNodeName, treeSHA1);
					return NO;
				}
			}
			if ([node aclSHA1] != nil) {
				printf("verifying aclSHA1 for node %s\n", [childPath UTF8String]);
				if (![self verify:[node aclSHA1] error:error]) {
					HSLogError(@"missing acl sha1 %@ for node %@ in tree %@", [node aclSHA1], childNodeName, treeSHA1);
					return NO;
				}
			}
        }
    }
    return YES;
}
- (BOOL)verify:(NSString *)sha1 error:(NSError **)error {
    if (sha1 != nil) {
        NSString *packSHA1 = nil;
        if (![repo packSHA1:&packSHA1 forPackedBlobSHA1:sha1 error:error]) {
            return NO;
        }
        if (packSHA1 != nil) {
            printf("sha1 %s: pack set %s, packSHA1 %s\n", [sha1 UTF8String], [[repo blobsPackSetName] UTF8String], [packSHA1 UTF8String]);
        } else {
            if (![objectSHA1s containsObject:sha1]) {
                SETNSERROR(@"VerifierErrorDomain", ERROR_NOT_FOUND, @"sha1 %@ not found in blobs packset or objects", sha1);
                return NO;
            }
			printf("sha1 %s: blob\n", [sha1 UTF8String]);
        }
	}
	return YES;
}

@end
