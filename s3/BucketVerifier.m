//
//  BucketVerifier.m
//  arq_restore
//
//  Created by Stefan Reitshamer on 6/17/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "BucketVerifier.h"
#import "S3Service.h"
#import "S3Fark.h"
#import "S3Repo.h"
#import "Commit.h"
#import "Tree.h"
#import "Node.h"
#import "SetNSError.h"

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
		fark = [[S3Fark alloc] initWithS3Service:s3 s3BucketName:s3BucketName computerUUID:computerUUID];
		repo = [[S3Repo alloc] initWithS3Service:s3 s3BucketName:s3BucketName computerUUID:computerUUID bucketUUID:bucketUUID encrypted:YES encryptionKey:encryptionKey fark:fark ensureCacheIntegrity:YES];
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
	printf("reloading packs from S3 for s3Bucket %s computerUUID %s bucketUUID %s\n", [s3BucketName UTF8String], [computerUUID UTF8String], [bucketUUID UTF8String]);
	NSArray *s3PackSHA1s = [fark reloadPacksFromS3:error];
	if (s3PackSHA1s == nil) {
		return NO;
	}
	printf("S3 packs found for computer UUID %s:\n", [computerUUID UTF8String]);
	for (NSString *s3PackSHA1 in s3PackSHA1s) {
		printf("S3 pack SHA1: %s\n", [s3PackSHA1 UTF8String]);
	}
	
	NSString *headSHA1 = nil;
	if (![repo localHeadSHA1:&headSHA1 error:error]) {
		return NO;
	}
	if (headSHA1 == nil) {
		printf("no head commit for s3Bucket %s computerUUID %s bucketUUID %s\n", [s3BucketName UTF8String], [computerUUID UTF8String], [bucketUUID UTF8String]);
		return YES;
	}
	printf("head commit for s3Bucket %s computerUUID %s bucketUUID %s is %s\n", [s3BucketName UTF8String], [computerUUID UTF8String], [bucketUUID UTF8String], [headSHA1 UTF8String]);
	NSString *commitSHA1 = headSHA1;
	while (commitSHA1 != nil) {
		printf("verifying commit %s bucketUUID %s\n", [commitSHA1 UTF8String], [bucketUUID UTF8String]);
		Commit *commit = nil;
		if (![repo commit:&commit forSHA1:commitSHA1 error:error]) {
			return NO;
		}
		printf("commit %s's tree is %s\n", [commitSHA1 UTF8String], [[commit treeSHA1] UTF8String]);
		if (![self verifyTree:[commit treeSHA1] path:@"/" error:error]) {
			return NO;
		}
		commitSHA1 = [[commit parentCommitSHA1s] anyObject];
	}
	return YES;
}
@end

@implementation BucketVerifier (internal)
- (BOOL)verifyTree:(NSString *)treeSHA1 path:(NSString *)path error:(NSError **)error {
	printf("verifying tree %s (path %s)\n", [treeSHA1 UTF8String], [path UTF8String]);
	Tree *tree = nil;
	if (![repo tree:&tree forSHA1:treeSHA1 error:error]) {
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
		if ([objectSHA1s containsObject:sha1]) {
			printf("sha1 %s: blob\n", [sha1 UTF8String]);
		} else if ([repo containsBlobForSHA1:sha1 packSetName:[repo blobsPackSetName] searchPackOnly:YES]) {
			printf("sha1 %s: pack set %s, packSHA1 %s\n", [sha1 UTF8String], [[repo blobsPackSetName] UTF8String], [[repo packSHA1ForPackedBlobSHA1:sha1 packSetName:[repo blobsPackSetName]] UTF8String]);
		} else {
			SETNSERROR(@"VerifierErrorDomain", -1, @"sha1 %@ not found", sha1);
			return NO;
		}
	}
	return YES;
}

@end
