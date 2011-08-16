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
#import "NSError_extra.h"
#import "NSErrorCodes.h"
#import "ArqSalt.h"
#import "ArqRepo.h"

@interface ArqVerifyCommand (internal)
- (BOOL)loadObjectSHA1sForS3BucketName:(NSString *)s3BucketName computerUUID:(NSString *)computerUUID error:(NSError **)error;
@end

@implementation ArqVerifyCommand
- (id)initWithAccessKey:(NSString *)theAccessKey secretKey:(NSString *)theSecretKey encryptionPassword:(NSString *)theEncryptionPassword {
    if (self = [super init]) {
		accessKey = [theAccessKey retain];
		secretKey = [theSecretKey retain];
		encryptionPassword = [theEncryptionPassword retain];
		S3AuthorizationProvider *sap = [[S3AuthorizationProvider alloc] initWithAccessKey:accessKey secretKey:secretKey];
		s3 = [[S3Service alloc] initWithS3AuthorizationProvider:sap useSSL:NO retryOnTransientError:YES];
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
- (void)setVerbose:(BOOL)isVerbose {
    verbose = isVerbose;
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
        if ([myError isErrorWithDomain:[S3Service errorDomain] code:ERROR_NOT_FOUND]) {
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
	printf("\nverifying computerUUID %s s3Bucket %s\n", [computerUUID UTF8String], [s3BucketName UTF8String]);
	NSString *computerBucketsPrefix = [NSString stringWithFormat:@"/%@/%@/buckets", s3BucketName, computerUUID];
	NSArray *s3BucketUUIDPaths = [s3 pathsWithPrefix:computerBucketsPrefix error:error];
	if (s3BucketUUIDPaths == nil) {
		return NO;
	}
    
    NSMutableArray *bucketUUIDs = [NSMutableArray array];
	for (NSString *s3BucketUUIDPath in s3BucketUUIDPaths) {
        NSString *bucketUUID = [s3BucketUUIDPath lastPathComponent];
        printf("found bucket UUID %s\n", [bucketUUID UTF8String]);
        [bucketUUIDs addObject:bucketUUID];
    }
    
    [objectSHA1s release];
    objectSHA1s = nil;
    if (![self loadObjectSHA1sForS3BucketName:s3BucketName computerUUID:computerUUID error:error]) {
        return NO;
    }
    
    BOOL ret = YES;
    NSAutoreleasePool *pool = nil;
    for (NSString *bucketUUID in bucketUUIDs) {
        [pool release];
        pool = [[NSAutoreleasePool alloc] init];
        if (![self verifyS3BucketName:s3BucketName computerUUID:computerUUID bucketUUID:bucketUUID error:error]) {
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
- (BOOL)verifyS3BucketName:(NSString *)s3BucketName computerUUID:(NSString *)computerUUID bucketUUID:(NSString *)bucketUUID error:(NSError **)error {
    if (objectSHA1s == nil) {
        if (![self loadObjectSHA1sForS3BucketName:s3BucketName computerUUID:computerUUID error:error]) {
            return NO;
        }
    }
    
    NSError *saltError = nil;
    ArqSalt *arqSalt = [[[ArqSalt alloc] initWithAccessKeyID:accessKey secretAccessKey:secretKey s3BucketName:s3BucketName computerUUID:computerUUID] autorelease];
    NSData *salt = [arqSalt salt:&saltError];
    if (salt == nil) {
        if ([saltError code] != ERROR_NOT_FOUND) {
            if (error != NULL) {
                *error = saltError;
            }
            return NO;
        }
    }
    ArqRepo *repo = [[[ArqRepo alloc] initWithS3Service:s3
                                           s3BucketName:s3BucketName
                                           computerUUID:computerUUID
                                             bucketUUID:bucketUUID
                                     encryptionPassword:encryptionPassword
                                                   salt:salt
                                                  error:error] autorelease];
    if (repo == nil) {
        return NO;
    }
    printf("\nverifying bucketUUID %s computerUUID %s s3Bucket %s\n", [bucketUUID UTF8String], [computerUUID UTF8String], [s3BucketName UTF8String]);
    
	BucketVerifier *bucketVerifier = [[[BucketVerifier alloc] initWithS3Service:s3
																   s3BucketName:s3BucketName
																   computerUUID:computerUUID
																	 bucketUUID:bucketUUID
																  s3ObjectSHA1s:objectSHA1s
                                                                        verbose:verbose
                                                                           repo:repo] autorelease];
	if (![bucketVerifier verify:error]) {
		return NO;
	}
	return YES;
}
@end

@implementation ArqVerifyCommand (internal)
- (BOOL)loadObjectSHA1sForS3BucketName:(NSString *)s3BucketName computerUUID:(NSString *)computerUUID error:(NSError **)error {
	NSMutableSet *theObjectSHA1s = [NSMutableSet set];
	NSString *objectsPrefix = [NSString stringWithFormat:@"/%@/%@/objects", s3BucketName, computerUUID];
	printf("loading S3 object SHA1s with prefix %s\n", [objectsPrefix UTF8String]);
	NSArray *objectPaths = [s3 pathsWithPrefix:objectsPrefix error:error];
    if (objectPaths == nil) {
        return NO;
    }
    for (NSString *objectPath in objectPaths) {
        [theObjectSHA1s addObject:[objectPath lastPathComponent]];
    }
    objectSHA1s = [theObjectSHA1s retain];
    printf("loaded %u object SHA1s with prefix %s\n", [objectSHA1s count], [objectsPrefix UTF8String]);
    return YES;
}
@end
