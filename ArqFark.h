//
//  ArqFark.h
//  Arq
//
//  Created by Stefan Reitshamer on 6/22/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
@class S3Service;
@class ServerBlob;

@interface ArqFark : NSObject {
    S3Service *s3;
    NSString *s3BucketName;
    NSString *computerUUID;
    NSThread *creatorThread;
}
+ (NSString *)errorDomain;
- (id)initWithS3Service:(S3Service *)theS3
           s3BucketName:(NSString *)theS3BucketName
           computerUUID:(NSString *)theComputerUUID;
- (NSData *)bucketDataForRelativePath:(NSString *)bucketDataRelativePath error:(NSError **)error;
- (NSData *)dataForSHA1:(NSString *)sha1 error:(NSError **)error;
- (ServerBlob *)newServerBlobForSHA1:(NSString *)sha1 error:(NSError **)error;
@end
