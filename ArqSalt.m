//
//  ArqSalt.m
//  Arq
//
//  Created by Stefan Reitshamer on 7/16/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "ArqSalt.h"
#import "S3AuthorizationProvider.h"
#import "S3Service.h"
#import "Blob.h"
#import "BlobACL.h"
#import "NSFileManager_extra.h"
#import "UserLibrary_Arq.h"

#define SALT_LENGTH (8)

@interface ArqSalt (internal)
- (NSData *)createRandomSalt;
@end

@implementation ArqSalt
- (id)initWithAccessKeyID:(NSString *)theAccessKeyID
          secretAccessKey:(NSString *)theSecretAccessKey
             s3BucketName:(NSString *)theS3BucketName
             computerUUID:(NSString *)theComputerUUID {
    if (self = [super init]) {
        accessKeyID = [theAccessKeyID retain];
        secretAccessKey = [theSecretAccessKey retain];
        s3BucketName = [theS3BucketName retain];
        computerUUID = [theComputerUUID retain];
        localPath = [[NSString alloc] initWithFormat:@"%@/Cache.noindex/%@/%@/salt.dat", [UserLibrary arqUserLibraryPath], s3BucketName, computerUUID];
        s3Path = [[NSString alloc] initWithFormat:@"/%@/%@/salt", s3BucketName, computerUUID];
    }
    return self;
}
- (void)dealloc {
    [accessKeyID release];
    [secretAccessKey release];
    [s3BucketName release];
    [computerUUID release];
    [localPath release];
    [s3Path release];
    [super dealloc];
}

- (NSData *)salt:(NSError **)error {
    NSData *ret = [NSData dataWithContentsOfFile:localPath options:NSUncachedRead error:error];
    if (ret == nil) {
        S3AuthorizationProvider *sap = [[[S3AuthorizationProvider alloc] initWithAccessKey:accessKeyID secretKey:secretAccessKey] autorelease];
        S3Service *s3 = [[[S3Service alloc] initWithS3AuthorizationProvider:sap useSSL:YES retryOnTransientError:NO] autorelease];
        ret = [s3 dataAtPath:s3Path error:error];
        if (ret == nil) {
            return nil;
        }
        NSError *myError = nil;
        if (![[NSFileManager defaultManager] ensureParentPathExistsForPath:localPath error:&myError]
            || ![ret writeToFile:localPath options:NSAtomicWrite error:&myError]) {
            HSLogError(@"error caching salt data to %@: %@", localPath, myError);
        }
    }
    return ret;
}
@end

@implementation ArqSalt (internal)
- (NSData *)createRandomSalt {
    unsigned char buf[SALT_LENGTH];
    for (NSUInteger i = 0; i < SALT_LENGTH; i++) {
        buf[i] = (unsigned char)(rand() % 256);
    }
    return [[[NSData alloc] initWithBytes:buf length:SALT_LENGTH] autorelease];
}
@end
