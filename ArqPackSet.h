//
//  ArqPackSet.h
//  Arq
//
//  Created by Stefan Reitshamer on 6/22/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//


@class S3Service;
@class ServerBlob;

@interface ArqPackSet : NSObject {
    S3Service *s3;
    NSString *s3BucketName;
    NSString *computerUUID;
    NSString *packSetName;
    NSDictionary *packIndexEntries;
}
+ (NSString *)errorDomain;
- (id)initWithS3Service:(S3Service *)theS3
           s3BucketName:(NSString *)theS3BucketName
           computerUUID:(NSString *)theComputerUUID
            packSetName:(NSString *)thePackSetName;
- (NSString *)packSetName;
- (ServerBlob *)newServerBlobForSHA1:(NSString *)sha1 error:(NSError **)error;
- (BOOL)containsBlob:(BOOL *)contains forSHA1:(NSString *)sha1 packSHA1:(NSString **)packSHA1 error:(NSError **)error;
@end
