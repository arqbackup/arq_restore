//
//  FarkPath.m
//  Arq
//
//  Created by Stefan Reitshamer on 6/29/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "FarkPath.h"


@implementation FarkPath
+ (NSString *)s3PathForS3BucketName:(NSString *)s3BucketName computerUUID:(NSString *)computerUUID sha1:(NSString *)sha1 {
    return [NSString stringWithFormat:@"/%@/%@/objects/%@", s3BucketName, computerUUID, sha1];
}
+ (NSString *)s3PathForBucketDataRelativePath:(NSString *)bucketDataRelativePath s3BucketName:(NSString *)s3BucketName computerUUID:(NSString *)computerUUID {
    return [[NSString stringWithFormat:@"/%@/%@/bucketdata", s3BucketName, computerUUID] stringByAppendingPathComponent:bucketDataRelativePath];
}
@end
