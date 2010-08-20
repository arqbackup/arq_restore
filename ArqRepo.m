//
//  ArqRepo.m
//  Arq
//
//  Created by Stefan Reitshamer on 6/23/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "ArqRepo.h"
#import "ArqFark.h"
#import "ArqPackSet.h"
#import "Commit.h"
#import "Tree.h"
#import "NSErrorCodes.h"
#import "ServerBlob.h"
#import "DataInputStream.h"
#import "DecryptedInputStream.h"
#import "NSData-Encrypt.h"
#import "SetNSError.h"
#import "NSError_extra.h"

@implementation ArqRepo
+ (NSString *)errorDomain {
    return @"ArqRepoErrorDomain";
}
- (id)initWithS3Service:(S3Service *)theS3 
           s3BucketName:(NSString *)theS3BucketName 
           computerUUID:(NSString *)theComputerUUID
             bucketUUID:(NSString *)theBucketUUID 
          encryptionKey:(NSString *)theEncryptionKey {
    if (self = [super init]) {
        bucketUUID = [theBucketUUID retain];
        encryptionKey = [theEncryptionKey retain];
        arqFark = [[ArqFark alloc] initWithS3Service:theS3 s3BucketName:theS3BucketName computerUUID:theComputerUUID];
        treesPackSet = [[ArqPackSet alloc] initWithS3Service:theS3 s3BucketName:theS3BucketName computerUUID:theComputerUUID packSetName:[theBucketUUID stringByAppendingString:@"-trees"]];
        blobsPackSet = [[ArqPackSet alloc] initWithS3Service:theS3 s3BucketName:theS3BucketName computerUUID:theComputerUUID packSetName:[theBucketUUID stringByAppendingString:@"-blobs"]];
    }
    return self;
}
- (void)dealloc {
    [bucketUUID release];
    [encryptionKey release];
    [arqFark release];
    [treesPackSet release];
    [blobsPackSet release];
    [super dealloc];
}
- (NSString *)headSHA1:(NSError **)error {
    NSString *bucketDataPath = [NSString stringWithFormat:@"/%@/refs/heads/master", bucketUUID];
    NSError *myError = nil;
    NSData *data = [arqFark bucketDataForPath:bucketDataPath error:&myError];
    if (data == nil) {
        if ([myError isErrorWithDomain:[ArqFark errorDomain] code:ERROR_NOT_FOUND]) {
            SETNSERROR([ArqRepo errorDomain], ERROR_NOT_FOUND, @"no head for bucketUUID %@", bucketUUID);
        } else {
            if (error != NULL) {
                *error = myError;
            }
        }
        return nil;
    }
    return [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
}
- (Commit *)commitForSHA1:(NSString *)theSHA1 error:(NSError **)error {
    NSError *myError = nil;
    ServerBlob *sb = [treesPackSet newServerBlobForSHA1:theSHA1 error:&myError];
    if (sb == nil) {
        if ([myError isErrorWithDomain:[ArqPackSet errorDomain] code:ERROR_NOT_FOUND]) {
            HSLogDebug(@"commit %@ not found in pack set %@", theSHA1, [treesPackSet packSetName]);
            SETNSERROR([ArqRepo errorDomain], ERROR_NOT_FOUND, @"commit not found for sha1 %@", theSHA1);
        } else {
            HSLogError(@"commit not found for %@: %@", theSHA1, [myError localizedDescription]);
            if (error != NULL) {
                *error = myError;
            }
        }
        return nil;
    }
    NSData *data = [[sb slurp:error] decryptWithCipher:ARQ_DEFAULT_CIPHER_NAME key:encryptionKey error:error];
    [sb release];
    if (data == nil) {
        return nil;
    }
    DataInputStream *dis = [[DataInputStream alloc] initWithData:data];
    BufferedInputStream *bis = [[BufferedInputStream alloc] initWithUnderlyingStream:dis];
    Commit *commit = [[[Commit alloc] initWithBufferedInputStream:bis error:error] autorelease];
    [bis release];
    [dis release];
    return commit;
}

// Returns NO if commit not found:
- (Tree *)treeForSHA1:(NSString *)theSHA1 error:(NSError **)error {
    NSError *myError = nil;
    ServerBlob *sb = [treesPackSet newServerBlobForSHA1:theSHA1 error:error];
    if (sb == nil) {
        if ([myError isErrorWithDomain:[ArqPackSet errorDomain] code:ERROR_NOT_FOUND]) {
            HSLogDebug(@"tree %@ not found in pack set %@", theSHA1, [treesPackSet packSetName]);
            SETNSERROR([ArqRepo errorDomain], ERROR_NOT_FOUND, @"commit not found for sha1 %@", theSHA1);
        } else {
            HSLogError(@"tree not found for %@: %@", theSHA1, [myError localizedDescription]);
            if (error != NULL) {
                *error = myError;
            }
        }
        return nil;
    }
    NSData *data = [[sb slurp:error] decryptWithCipher:ARQ_DEFAULT_CIPHER_NAME key:encryptionKey error:error];
    [sb release];
    if (data == nil) {
        return nil;
    }
    DataInputStream *dis = [[DataInputStream alloc] initWithData:data];
    BufferedInputStream *bis = [[BufferedInputStream alloc] initWithUnderlyingStream:dis];
    Tree *tree = [[[Tree alloc] initWithBufferedInputStream:bis error:error] autorelease];
    [bis release];
    [dis release];
    return tree;
}
- (NSData *)blobDataForSHA1:(NSString *)sha1 error:(NSError **)error {
    ServerBlob *sb = [self newServerBlobForSHA1:sha1 error:error];
    if (sb == nil) {
        return nil;
    }
    NSData *data = [sb slurp:error];
    [sb release];
    return data;
}
- (NSData *)blobDataForSHA1s:(NSArray *)sha1s error:(NSError **)error {
    //FIXME: This is very inefficient!
    NSMutableData *ret = [NSMutableData data];
    for (NSString *sha1 in sha1s) {
        NSData *data = [self blobDataForSHA1:sha1 error:error];
        if (data == nil) {
            return nil;
        }
        [ret appendData:data];
    }
    return ret;
}
- (ServerBlob *)newServerBlobForSHA1:(NSString *)sha1 error:(NSError **)error {
    NSError *myError = nil;
    ServerBlob *sb = [blobsPackSet newServerBlobForSHA1:sha1 error:&myError];
    if (sb == nil) {
        if ([myError isErrorWithDomain:[ArqPackSet errorDomain] code:ERROR_NOT_FOUND]) {
            HSLogTrace(@"sha1 %@ not found in pack set %@; looking in S3", sha1, [blobsPackSet packSetName]);
            sb = [arqFark newServerBlobForSHA1:sha1 error:&myError];
            if (sb == nil) {
                if ([myError isErrorWithDomain:[ArqFark errorDomain] code:ERROR_NOT_FOUND]) {
                    SETNSERROR([ArqRepo errorDomain], ERROR_NOT_FOUND, @"sha1 %@ not found", sha1);
                } else {
                    if (error != NULL) {
                        *error = myError;
                    }
                }
            }
        } else {
            HSLogError(@"error trying to read from pack set: %@", [myError localizedDescription]);
            if (error != NULL) {
                *error = myError;
            }
        }
    }
    if (sb != nil) {
        id <InputStream> is = [sb newInputStream];
        NSString *mimeType = [sb mimeType];
        NSString *downloadName = [sb downloadName];
        [sb autorelease];
        sb = nil;
        DecryptedInputStream *dis = [[DecryptedInputStream alloc] initWithInputStream:is cipherName:ARQ_DEFAULT_CIPHER_NAME key:encryptionKey error:error];
        [is release];
        if (dis != nil) {
            sb = [[ServerBlob alloc] initWithInputStream:dis mimeType:mimeType downloadName:downloadName];
            [dis release];
        }
    }
    return sb;
}

#pragma mark NSObject
- (NSString *)description {
    return [NSString stringWithFormat:@"<ArqRepo: bucketUUID=%@>", bucketUUID];
}
@end
