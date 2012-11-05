//
//  FarkPath.h
//  Arq
//
//  Created by Stefan Reitshamer on 6/29/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//




@interface FarkPath : NSObject {

}
+ (NSString *)s3PathForS3BucketName:(NSString *)s3BucketName computerUUID:(NSString *)computerUUID sha1:(NSString *)sha1;
+ (NSString *)s3PathForBucketDataRelativePath:(NSString *)bucketDataRelativePath s3BucketName:(NSString *)s3BucketName computerUUID:(NSString *)computerUUID;
@end
