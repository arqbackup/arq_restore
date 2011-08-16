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
#import "ArqRepo.h"
#import "Commit.h"
#import "Tree.h"
#import "Node.h"
#import "SetNSError.h"
#import "NSError_extra.h"
#import "NSErrorCodes.h"
#import "BlobKey.h"

@interface BucketVerifier (internal)
+ (NSString *)errorDomain;

- (BOOL)verifyTree:(BlobKey *)theTreeBlobKey path:(NSString *)path error:(NSError **)error;
- (BOOL)verifyTree:(BlobKey *)theTreeBlobKey path:(NSString *)path childNodeName:(NSString *)childNodeName node:(Node *)node error:(NSError **)error;
- (BOOL)verify:(BlobKey *)theBlobKey error:(NSError **)error;
@end

@implementation BucketVerifier
- (id)initWithS3Service:(S3Service *)theS3
           s3BucketName:(NSString *)theS3BucketName
           computerUUID:(NSString *)theComputerUUID 
             bucketUUID:(NSString *)theBucketUUID
          s3ObjectSHA1s:(NSSet *)theObjectSHA1s 
                verbose:(BOOL)isVerbose
                   repo:(ArqRepo *)theRepo {
	if (self = [super init]) {
		s3 = [theS3 retain];
		s3BucketName = [theS3BucketName retain];
		computerUUID = [theComputerUUID retain];
		bucketUUID = [theBucketUUID retain];
		objectSHA1s = [theObjectSHA1s retain];
        verbose = isVerbose;
		repo = [theRepo retain];
	}
	return self;
}
- (void)dealloc {
	[s3 release];
	[s3BucketName release];
	[computerUUID release];
	[bucketUUID release];
	[objectSHA1s release];
	[repo release];
	[super dealloc];
}	
- (BOOL)verify:(NSError **)error {
    printf("verifying all objects exist for commits in %s\n", [bucketUUID UTF8String]);
	
    NSError *myError = nil;
    BlobKey *headBlobKey = [repo headBlobKey:&myError];
    if (headBlobKey == nil) {
        if ([myError isErrorWithDomain:[ArqRepo errorDomain] code:ERROR_NOT_FOUND]) {
            printf("no head commit for s3Bucket %s computerUUID %s bucketUUID %s\n", [s3BucketName UTF8String], [computerUUID UTF8String], [bucketUUID UTF8String]);
        } else {
            if (error != NULL) {
                *error = myError;
            }
            return NO;
        }
	} else {
        printf("head commit for s3Bucket %s computerUUID %s bucketUUID %s is %s\n", [s3BucketName UTF8String], [computerUUID UTF8String], [bucketUUID UTF8String], [[headBlobKey description] UTF8String]);
        BlobKey *commitBlobKey = headBlobKey;
        BOOL ret = YES;
        NSAutoreleasePool *pool = nil;
        while (commitBlobKey != nil) {
            [commitBlobKey retain];
            [pool drain];
            pool = [[NSAutoreleasePool alloc] init];
            [commitBlobKey autorelease];
            
            printf("verifying commit %s bucketUUID %s\n", [[commitBlobKey description] UTF8String], [bucketUUID UTF8String]);
            Commit *commit = [repo commitForBlobKey:commitBlobKey error:error];
            if (commit == nil) {
                ret = NO;
                break;
            }
            if (verbose) {
                printf("commit %s's tree is %s\n", [[commitBlobKey description] UTF8String], [[[commit treeBlobKey] description] UTF8String]);
            }
            if (![self verifyTree:[commit treeBlobKey] path:@"/" error:error]) {
                ret = NO;
                break;
            }
            commitBlobKey = [[commit parentCommitBlobKeys] anyObject];
        }
        if (!ret && error != NULL) {
            [*error retain];
        }
        [pool drain];
        if (!ret && error != NULL) {
            [*error autorelease];
        }
        if (!ret) {
            return NO;
        }
    }
    printf("%qu packed blobs; %qu non-packed blobs\n", packedBlobCount, nonPackedBlobCount);
	return YES;
}
@end

@implementation BucketVerifier (internal)
+ (NSString *)errorDomain {
    return @"BucketVerifierErrorDomain";
}

- (BOOL)verifyTree:(BlobKey *)theTreeBlobKey path:(NSString *)path error:(NSError **)error {
    if (verbose) {
        printf("verifying tree %s (path %s)\n", [[theTreeBlobKey description] UTF8String], [path UTF8String]);
    }
	Tree *tree = [repo treeForBlobKey:theTreeBlobKey error:error];
    if (tree == nil) {
        SETNSERROR([BucketVerifier errorDomain], -1, @"tree %@ not found", theTreeBlobKey);
		return NO;
	}
	if ([tree xattrsBlobKey] != nil) {
        if (verbose) {
            printf("verifying xattrs blobkey for tree %s\n", [[theTreeBlobKey description] UTF8String]);
        }
		if (![self verify:[tree xattrsBlobKey] error:error]) {
            SETNSERROR([BucketVerifier errorDomain], -1, @"tree %@ xattrs blobkey %@ not found", theTreeBlobKey, [tree xattrsBlobKey]);
			return NO;
		}
	}
	if ([tree aclBlobKey] != nil) {
        if (verbose) {
            printf("verifying aclSHA1 for tree %s\n", [[theTreeBlobKey description] UTF8String]);
        }
		if (![self verify:[tree aclBlobKey] error:error]) {
            SETNSERROR([BucketVerifier errorDomain], -1, @"tree %@ acl blobkey %@ not found", theTreeBlobKey, [tree aclBlobKey]);
			return NO;
		}
	}
    BOOL ret = YES;
    NSArray *childNodeNames = [tree childNodeNames];
    NSAutoreleasePool *pool = nil;
    for (NSString *childNodeName in childNodeNames) {
        [childNodeName retain];
        [pool release];
        pool = [[NSAutoreleasePool alloc] init];
        [childNodeName autorelease];
        
        Node *node = [tree childNodeWithName:childNodeName];
        if (![self verifyTree:theTreeBlobKey path:path childNodeName:childNodeName node:node error:error]) {
            ret = NO;
            break;
        }
    }
    if (!ret && error != NULL) {
        [*error retain];
    }
    [pool drain];
    if (!ret && error != NULL) {
        [*error autorelease];
    }
    return ret;
}
- (BOOL)verifyTree:(BlobKey *)theTreeBlobKey path:(NSString *)path childNodeName:(NSString *)childNodeName node:(Node *)node error:(NSError **)error {
    NSArray *dataBlobKeys = [node dataBlobKeys];
    NSString *childPath = [path stringByAppendingPathComponent:childNodeName];
    if ([node isTree]) {
        NSAssert([dataBlobKeys count] == 1, ([NSString stringWithFormat:@"tree %@ node %@ must have exactly 1 dataBlobKey", [[theTreeBlobKey description] UTF8String], childNodeName]));
        if (![self verifyTree:[dataBlobKeys objectAtIndex:0] path:childPath error:error]) {
            return NO;
        }
    } else {
        if (verbose) {
            printf("verifying data sha1s for node %s\n", [childPath UTF8String]);
        }
        for (BlobKey *dataBlobKey in dataBlobKeys) {
            if (![self verify:dataBlobKey error:error]) {
                SETNSERROR([BucketVerifier errorDomain], -1, @"missing data blobkey %@ for node %@ in tree %@", dataBlobKey, childNodeName, theTreeBlobKey);
                return NO;
            }
        }
        if ([node thumbnailBlobKey] != nil) {
            if (verbose) {
                printf("verifying thumbnailSHA1 for node %s\n", [childPath UTF8String]);
            }
            if (![self verify:[node thumbnailBlobKey] error:error]) {
                SETNSERROR([BucketVerifier errorDomain], -1, @"missing thumbnail blobkey %@ for node %@ in tree %@", [node thumbnailBlobKey], childNodeName, theTreeBlobKey);
                return NO;
            }
        }
        if ([node previewBlobKey] != nil) {
            if (verbose) {
                printf("verifying previewSHA1 for node %s\n", [childPath UTF8String]);
            }
            if (![self verify:[node previewBlobKey] error:error]) {
                SETNSERROR([BucketVerifier errorDomain], -1, @"missing preview blobkey %@ for node %@ in tree %@", [node previewBlobKey], childNodeName, theTreeBlobKey);
                return NO;
            }
        }
        if ([node xattrsBlobKey] != nil) {
            if (verbose) {
                printf("verifying xattrsSHA1 for node %s\n", [childPath UTF8String]);
            }
            if (![self verify:[node xattrsBlobKey] error:error]) {
                SETNSERROR([BucketVerifier errorDomain], -1, @"missing xattrs blobkey %@ for node %@ in tree %@", [node xattrsBlobKey], childNodeName, theTreeBlobKey);
                return NO;
            }
        }
        if ([node aclBlobKey] != nil) {
            if (verbose) {
                printf("verifying aclSHA1 for node %s\n", [childPath UTF8String]);
            }
            if (![self verify:[node aclBlobKey] error:error]) {
                SETNSERROR([BucketVerifier errorDomain], -1, @"missing acl blobkey %@ for node %@ in tree %@", [node aclBlobKey], childNodeName, theTreeBlobKey);
                return NO;
            }
        }
    }
    return YES;
}
- (BOOL)verify:(BlobKey *)theBlobKey error:(NSError **)error {
    if (theBlobKey == nil) {
        return YES;
    }
    
    if ([objectSHA1s containsObject:[theBlobKey sha1]]) {
        if (verbose) {
            printf("blobkey %s: blob\n", [[theBlobKey description] UTF8String]);
        }
        nonPackedBlobCount++;
        return YES;
    }
    
    BOOL contains = NO;
    NSString *packSetName = nil;
    NSString *packSHA1 = nil;
    if (![repo containsPackedBlob:&contains forBlobKey:theBlobKey packSetName:&packSetName packSHA1:&packSHA1 error:error]) {
        return NO;
    }
    if (contains) {
        if (verbose) {
            printf("blobkey %s: pack set %s, packSHA1 %s\n", [[theBlobKey description] UTF8String], [packSetName UTF8String], [packSHA1 UTF8String]);
        }
        packedBlobCount++;
        return YES;
    }        
    
    SETNSERROR([BucketVerifier errorDomain], ERROR_NOT_FOUND, @"blobkey %@ not found in packsets or objects", theBlobKey);
    return NO;
}

@end
