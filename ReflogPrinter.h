//
//  ReflogPrinter.h
//  arq_restore
//
//  Created by Stefan Reitshamer on 11/21/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//


@class S3Service;
@class ArqRepo;

@interface ReflogPrinter : NSObject {
    NSString *s3BucketName;
    NSString *computerUUID;
    NSString *bucketUUID;
    S3Service *s3;
    ArqRepo *repo;
}
- (id)initWithS3BucketName:(NSString *)theS3BucketName computerUUID:(NSString *)theComputerUUID bucketUUID:(NSString *)theBucketUUID s3:(S3Service *)theS3 repo:(ArqRepo *)theRepo;
- (BOOL)printReflog:(NSError **)error;
@end
