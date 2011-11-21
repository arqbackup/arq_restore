//
//  ReflogPrinter.m
//  arq_restore
//
//  Created by Stefan Reitshamer on 11/21/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "ReflogPrinter.h"
#import "S3Service.h"
#import "ArqRepo.h"
#import "ReflogEntry.h"
#import "Commit.h"
#import "BlobKey.h"


@interface ReflogPrinter (internal)
- (BOOL)printEntry:(NSString *)path error:(NSError **)error;
@end


@implementation ReflogPrinter
- (id)initWithS3BucketName:(NSString *)theS3BucketName computerUUID:(NSString *)theComputerUUID bucketUUID:(NSString *)theBucketUUID s3:(S3Service *)theS3 repo:(ArqRepo *)theRepo {
    if (self = [super init]) {
        s3BucketName = [theS3BucketName retain];
        computerUUID = [theComputerUUID retain];
        bucketUUID = [theBucketUUID retain];
        s3 = [theS3 retain];
        repo = [theRepo retain];
    }
    return self;
}
- (void)dealloc {
    [s3BucketName release];
    [computerUUID release];
    [bucketUUID release];
    [s3 release];
    [repo release];
    [super dealloc];
}

- (BOOL)printReflog:(NSError **)error {
    NSString *prefix = [NSString stringWithFormat:@"/%@/%@/bucketdata/%@/refs/logs/master/", s3BucketName, computerUUID, bucketUUID];
    NSArray *paths = [s3 pathsWithPrefix:prefix error:error];
    if (paths == nil) {
        return NO;
    }
    NSSortDescriptor *descriptor = [[[NSSortDescriptor alloc] initWithKey:@"description" ascending:NO] autorelease];
    NSArray *sortedPaths = [paths sortedArrayUsingDescriptors:[NSArray arrayWithObject:descriptor]];
    
    BOOL ret = YES;
    NSAutoreleasePool *pool = nil;
    for (NSString *path in sortedPaths) {
        [pool drain];
        pool = [[NSAutoreleasePool alloc] init];
        if (![self printEntry:path error:error]) {
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
@end

@implementation ReflogPrinter (internal)
- (BOOL)printEntry:(NSString *)path error:(NSError **)error {
    printf("reflog %s\n", [path UTF8String]);
    
    NSData *data = [s3 dataAtPath:path error:error];
    if (data == nil) {
        return NO;
    }
    NSError *myError = nil;
    ReflogEntry *entry = [[[ReflogEntry alloc] initWithData:data error:&myError] autorelease];
    if (entry == nil) {
        printf("\terror reading reflog entry: %s\n", [[myError description] UTF8String]);
    } else {
        Commit *commit = [repo commitForBlobKey:[entry newHeadBlobKey] error:&myError];
        if (commit == nil) {
            printf("\tcommit %s: %s\n", [[[entry newHeadBlobKey] description] UTF8String], [[myError localizedDescription] UTF8String]);
        } else {
            printf("\tblobkey: %s\n", [[[entry newHeadBlobKey] description] UTF8String]);
            printf("\tauthor: %s\n", [[commit author] UTF8String]);
            printf("\tdate: %s\n", [[[commit creationDate] description] UTF8String]);
            printf("\tlocation: %s\n", [[commit location] UTF8String]);
            printf("\trestore command: arq_restore /%s/%s/buckets/%s %s\n", [s3BucketName UTF8String], [computerUUID UTF8String], [bucketUUID UTF8String], 
                   [[[entry newHeadBlobKey] sha1] UTF8String]);
        }
    }
    return YES;
}
@end
