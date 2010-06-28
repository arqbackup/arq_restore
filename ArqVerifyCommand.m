//
//  ArqVerifyCommand.m
//  arq_restore
//
//  Created by Stefan Reitshamer on 6/17/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "ArqVerifyCommand.h"
#import "S3AuthorizationProvider.h"
#import "S3Service.h"
#import "HTTP.h"
#import "RegexKitLite.h"
#import "BucketVerifier.h"
#import "PackSet.h"

@interface ArqVerifyCommand (internal)
- (NSArray *)objectSHA1sForS3BucketName:(NSString *)s3BucketName computerUUID:(NSString *)computerUUID error:(NSError **)error;
@end

@implementation ArqVerifyCommand
- (id)initWithAccessKey:(NSString *)theAccessKey secretKey:(NSString *)theSecretKey encryptionPassword:(NSString *)theEncryptionPassword {
    if (self = [super init]) {
		accessKey = [theAccessKey retain];
		secretKey = [theSecretKey retain];
		encryptionPassword = [theEncryptionPassword retain];
		S3AuthorizationProvider *sap = [[S3AuthorizationProvider alloc] initWithAccessKey:accessKey secretKey:secretKey];
		s3 = [[S3Service alloc] initWithS3AuthorizationProvider:sap useSSL:NO retryOnNetworkError:YES];
		[sap release];
    }
    return self;
}
- (void)dealloc {
    [accessKey release];
    [secretKey release];
    [encryptionPassword release];
    [s3 release];
    [super dealloc];
}
- (BOOL)verifyAll:(NSError **)error {
	NSArray *s3BucketNames = [S3Service s3BucketNamesForAccessKeyID:accessKey];
	for (NSString *s3BucketName in s3BucketNames) {
		printf("s3bucket name: %s\n", [s3BucketName UTF8String]);
	}
	for (NSString *s3BucketName in s3BucketNames) {
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		BOOL ret = [self verifyS3BucketName:s3BucketName error:error];
		if (error != NULL) {
			[*error retain];
		}
		[pool drain];
		if (error != NULL) {
			[*error autorelease];
		}
		if (!ret) {
			return NO;
		}
	}
	return YES;
}
- (BOOL)verifyS3BucketName:(NSString *)s3BucketName error:(NSError **)error {
	printf("verifying s3Bucket %s\n", [s3BucketName UTF8String]);
	NSString *computerUUIDPrefix = [NSString stringWithFormat:@"/%@/", s3BucketName];
	NSError *myError = nil;
	NSArray *computerUUIDs = [s3 commonPrefixesForPathPrefix:computerUUIDPrefix delimiter:@"/" error:&myError];
	if (computerUUIDs == nil) {
		if ([[myError domain] isEqualToString:[S3Service serverErrorDomain]] && [myError code] == HTTP_NOT_FOUND) {
			// Skip.
			printf("no computer UUIDs found in bucket %s\n", [s3BucketName UTF8String]);
			return YES;
		} else {
			if (error != NULL) {
				*error = myError;
			}
			return NO;
		}
	}
	for (NSString *computerUUID in computerUUIDs) {
		printf("found computer UUID %s\n", [computerUUID UTF8String]);
	}
	for (NSString *computerUUID in computerUUIDs) {
		if (![self verifyS3BucketName:s3BucketName computerUUID:computerUUID error:error]) {
			return NO;
		}
	}
	return YES;
}
- (BOOL)verifyS3BucketName:(NSString *)s3BucketName computerUUID:(NSString *)computerUUID error:(NSError **)error {
	printf("verifying computerUUID %s s3Bucket %s\n", [computerUUID UTF8String], [s3BucketName UTF8String]);
	NSString *computerBucketsPrefix = [NSString stringWithFormat:@"/%@/%@/buckets", s3BucketName, computerUUID];
	NSArray *s3BucketUUIDPaths = [s3 pathsWithPrefix:computerBucketsPrefix error:error];
	if (s3BucketUUIDPaths == nil) {
		return NO;
	}
	NSArray *objectSHA1s = [self objectSHA1sForS3BucketName:s3BucketName computerUUID:computerUUID error:error];
	if (objectSHA1s == nil) {
		return NO;
	}
	for (NSString *s3BucketUUIDPath in s3BucketUUIDPaths) {
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		NSString *bucketUUID = [s3BucketUUIDPath lastPathComponent];
		printf("verifying bucketUUID %s computerUUID %s s3Bucket %s\n", [bucketUUID UTF8String], [computerUUID UTF8String], [s3BucketName UTF8String]);
		BucketVerifier *bucketVerifier = [[[BucketVerifier alloc] initWithS3Service:s3
																	   s3BucketName:s3BucketName
																	   computerUUID:computerUUID
																		 bucketUUID:bucketUUID
																	  s3ObjectSHA1s:objectSHA1s
																	  encryptionKey:encryptionPassword] autorelease];
		BOOL ret = [bucketVerifier verify:error];
		if (error != NULL) {
			[*error retain];
		}
		[pool drain];
		if (error != NULL) {
			[*error autorelease];
		}
		if (!ret) {
			return NO;
		}
	}
	return YES;
}
- (BOOL)verifyS3BucketName:(NSString *)s3BucketName computerUUID:(NSString *)computerUUID bucketUUID:(NSString *)bucketUUID error:(NSError **)error {
	NSArray *objectSHA1s = [self objectSHA1sForS3BucketName:s3BucketName computerUUID:computerUUID error:error];
	if (objectSHA1s == nil) {
		return NO;
	}
	printf("verifying bucketUUID %s computerUUID %s s3Bucket %s\n", [bucketUUID UTF8String], [computerUUID UTF8String], [s3BucketName UTF8String]);
	BucketVerifier *bucketVerifier = [[[BucketVerifier alloc] initWithS3Service:s3
																   s3BucketName:s3BucketName
																   computerUUID:computerUUID
																	 bucketUUID:bucketUUID
																  s3ObjectSHA1s:objectSHA1s
																  encryptionKey:encryptionPassword] autorelease];
	if (![bucketVerifier verify:error]) {
		return NO;
	}
	return YES;
}
@end

@implementation ArqVerifyCommand (internal)
- (NSArray *)objectSHA1sForS3BucketName:(NSString *)s3BucketName computerUUID:(NSString *)computerUUID error:(NSError **)error {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSMutableArray *objectSHA1s = nil;
	NSString *objectsPrefix = [NSString stringWithFormat:@"/%@/%@/objects", s3BucketName, computerUUID];
	printf("loading S3 object SHA1s with prefix %s\n", [objectsPrefix UTF8String]);
	NSArray *objectPaths = [s3 pathsWithPrefix:objectsPrefix error:error];
	if (objectPaths != nil) {
		objectSHA1s = [[NSMutableArray alloc] init];
		printf("loaded %u object SHA1s with prefix %s\n", [objectPaths count], [objectsPrefix UTF8String]);
		for (NSString *objectPath in objectPaths) {
			[objectSHA1s addObject:[objectPath lastPathComponent]];
		}
	}
	if (error != NULL) {
		[*error retain];
	}
	[pool drain];
	[objectSHA1s autorelease];
	if (error != NULL) {
		[*error autorelease];
	}
	return objectSHA1s;
}
@end
