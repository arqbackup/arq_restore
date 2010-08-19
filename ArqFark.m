//
//  ArqFark.m
//  Arq
//
//  Created by Stefan Reitshamer on 6/22/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "ArqFark.h"
#import "ArqPackSet.h"
#import "ServerBlob.h"
#import "NSErrorCodes.h"
#import "S3Service.h"
#import "RegexKitLite.h"
#import "DiskPackIndex.h"
#import "FarkPath.h"
#import "SetNSError.h"
#import "NSError_extra.h"

#define MAX_RETRIES 10

@implementation ArqFark
+ (NSString *)errorDomain {
    return @"ArqFarkErrorDomain";
}
- (id)initWithS3Service:(S3Service *)theS3
           s3BucketName:(NSString *)theS3BucketName
           computerUUID:(NSString *)theComputerUUID {
    if (self = [super init]) {
        s3 = [theS3 retain];
        s3BucketName = [theS3BucketName retain];
        computerUUID = [theComputerUUID retain];
        creatorThread = [[NSThread currentThread] retain];
    }
    return self;
}
- (void)dealloc {
    [s3 release];
    [s3BucketName release];
    [computerUUID release];
    [creatorThread release];
    [super dealloc];
}
- (NSData *)bucketDataForPath:(NSString *)bucketDataPath error:(NSError **)error {
    NSAssert([NSThread currentThread] == creatorThread, @"must be on same thread!");
    
    NSError *myError = nil;
    NSData *data = [s3 dataAtPath:[FarkPath s3PathForBucketDataPath:bucketDataPath s3BucketName:s3BucketName computerUUID:computerUUID] error:&myError];
    if (data == nil) {
        if ([myError isErrorWithDomain:[S3Service errorDomain] code:ERROR_NOT_FOUND]) {
            SETNSERROR([ArqFark errorDomain], ERROR_NOT_FOUND, @"bucket data not found for path %@", bucketDataPath);
        } else {
            if (error != NULL) {
                *error = myError;
            }
        }
    }
    return data;
}
- (NSData *)dataForSHA1:(NSString *)sha1 error:(NSError **)error {
    ServerBlob *sb = [self newServerBlobForSHA1:sha1 error:error];
    if (sb == nil) {
        return nil;
    }
    NSData *data = [sb slurp:error];
    [sb release];
    return data;
}
- (ServerBlob *)newServerBlobForSHA1:(NSString *)sha1 error:(NSError **)error {
    NSAssert([NSThread currentThread] == creatorThread, @"must be on same thread!");
    NSString *s3Path = [NSString stringWithFormat:@"/%@/%@/objects/%@", s3BucketName, computerUUID, sha1];
    return [s3 newServerBlobAtPath:s3Path error:error];
}
@end
