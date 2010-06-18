//
//  BucketVerifier.h
//  arq_restore
//
//  Created by Stefan Reitshamer on 6/17/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
@class S3Service;
@class S3Fark;
@class S3Repo;

@interface BucketVerifier : NSObject {
	S3Service *s3;
	NSString *s3BucketName;
	NSString *computerUUID;
	NSString *bucketUUID;
	NSArray *objectSHA1s;
	S3Fark *fark;
	S3Repo *repo;
}
- (id)initWithS3Service:(S3Service *)theS3 s3BucketName:(NSString *)theS3BucketName computerUUID:(NSString *)theComputerUUID bucketUUID:(NSString *)theBucketUUID s3ObjectSHA1s:(NSArray *)theObjectSHA1s encryptionKey:(NSString *)encryptionKey;
- (BOOL)verify:(NSError **)error;
@end
