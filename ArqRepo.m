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
#import "GunzipInputStream.h"
#import "CryptoKey.h"
#import "BlobKey.h"
#import "Encryption.h"

@implementation ArqRepo
+ (NSString *)errorDomain {
    return @"ArqRepoErrorDomain";
}
- (id)initWithS3Service:(S3Service *)theS3 
           s3BucketName:(NSString *)theS3BucketName 
           computerUUID:(NSString *)theComputerUUID
             bucketUUID:(NSString *)theBucketUUID 
     encryptionPassword:(NSString *)theEncryptionPassword 
                   salt:(NSData *)theEncryptionSalt
                  error:(NSError **)error {
    if (self = [super init]) {
        bucketUUID = [theBucketUUID retain];
        
        if (theEncryptionPassword == nil) {
            SETNSERROR([Encryption errorDomain], -1, @"missing encryption password");
            [self release];
            return nil;
        }
        
        cryptoKey = [[CryptoKey alloc] initLegacyWithPassword:theEncryptionPassword error:error];
        if (cryptoKey == nil) {
            [self release];
            return nil;
        }
        stretchedCryptoKey = [[CryptoKey alloc] initWithPassword:theEncryptionPassword salt:theEncryptionSalt error:error];
        if (stretchedCryptoKey == nil) {
            [self release];
            return nil;
        }

        arqFark = [[ArqFark alloc] initWithS3Service:theS3 s3BucketName:theS3BucketName computerUUID:theComputerUUID];
        treesPackSet = [[ArqPackSet alloc] initWithS3Service:theS3 s3BucketName:theS3BucketName computerUUID:theComputerUUID packSetName:[theBucketUUID stringByAppendingString:@"-trees"]];
        blobsPackSet = [[ArqPackSet alloc] initWithS3Service:theS3 s3BucketName:theS3BucketName computerUUID:theComputerUUID packSetName:[theBucketUUID stringByAppendingString:@"-blobs"]];
    }
    return self;
}
- (void)dealloc {
    [bucketUUID release];
    [cryptoKey release];
    [stretchedCryptoKey release];
    [arqFark release];
    [treesPackSet release];
    [blobsPackSet release];
    [super dealloc];
}
- (NSString *)bucketUUID {
    return bucketUUID;
}
- (BlobKey *)headBlobKey:(NSError **)error {
    NSString *bucketDataRelativePath = [NSString stringWithFormat:@"/%@/refs/heads/master", bucketUUID];
    NSError *myError = nil;
    NSData *data = [arqFark bucketDataForRelativePath:bucketDataRelativePath error:&myError];
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
    NSString *sha1 = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
    BOOL stretch = NO;
    if ([sha1 length] > 40) {
        stretch = [sha1 characterAtIndex:40] == 'Y';
        sha1 = [sha1 substringToIndex:40];
    }
    return [[[BlobKey alloc] initWithSHA1:sha1 stretchEncryptionKey:stretch] autorelease];
}
- (Commit *)commitForBlobKey:(BlobKey *)commitBlobKey error:(NSError **)error {
    NSError *myError = nil;
    ServerBlob *sb = [treesPackSet newServerBlobForSHA1:[commitBlobKey sha1] error:&myError];
    if (sb == nil) {
        if ([myError isErrorWithDomain:[ArqPackSet errorDomain] code:ERROR_NOT_FOUND]) {
            HSLogDebug(@"commit %@ not found in pack set %@", commitBlobKey, [treesPackSet packSetName]);
            SETNSERROR([ArqRepo errorDomain], ERROR_NOT_FOUND, @"commit %@ not found", commitBlobKey);
        } else {
            HSLogError(@"commit %@ not found for: %@", commitBlobKey, [myError localizedDescription]);
            if (error != NULL) {
                *error = myError;
            }
        }
        return nil;
    }
    NSData *encrypted = [sb slurp:error];
    [sb release];
    if (encrypted == nil) {
        return nil;
    }
    NSData *data = [encrypted decryptWithCryptoKey:([commitBlobKey stretchEncryptionKey] ? stretchedCryptoKey : cryptoKey) error:error];
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
- (Tree *)treeForBlobKey:(BlobKey *)blobKey error:(NSError **)error {
    NSError *myError = nil;
    ServerBlob *sb = [treesPackSet newServerBlobForSHA1:[blobKey sha1] error:&myError];
    if (sb == nil) {
        if ([myError isErrorWithDomain:[ArqPackSet errorDomain] code:ERROR_NOT_FOUND]) {
            HSLogDebug(@"tree %@ not found in pack set %@", blobKey, [treesPackSet packSetName]);
            SETNSERROR([ArqRepo errorDomain], ERROR_NOT_FOUND, @"tree %@ not found", blobKey);
        } else {
            HSLogError(@"error reading tree %@: %@", blobKey, [myError localizedDescription]);
            if (error != NULL) {
                *error = myError;
            }
        }
        return nil;
    }
    NSData *encrypted = [sb slurp:error];
    [sb release];
    if (encrypted == nil) {
        return nil;
    }
    NSData *data = [encrypted decryptWithCryptoKey:([blobKey stretchEncryptionKey] ? stretchedCryptoKey : cryptoKey) error:error];
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
- (NSData *)blobDataForBlobKey:(BlobKey *)treeBlobKey error:(NSError **)error {
    ServerBlob *sb = [self newServerBlobForBlobKey:treeBlobKey error:error];
    if (sb == nil) {
        return nil;
    }
    NSData *data = [sb slurp:error];
    [sb release];
    return data;
}
- (ServerBlob *)newServerBlobForBlobKey:(BlobKey *)theBlobKey error:(NSError **)error {
    NSError *myError = nil;
    ServerBlob *sb = [blobsPackSet newServerBlobForSHA1:[theBlobKey sha1] error:&myError];
    if (sb == nil) {
        if ([myError isErrorWithDomain:[ArqPackSet errorDomain] code:ERROR_NOT_FOUND]) {
            HSLogTrace(@"%@ not found in pack set %@; looking in S3", theBlobKey, [blobsPackSet packSetName]);
            sb = [arqFark newServerBlobForSHA1:[theBlobKey sha1] error:&myError];
            if (sb == nil) {
                if ([myError isErrorWithDomain:[ArqFark errorDomain] code:ERROR_NOT_FOUND]) {
                    SETNSERROR([ArqRepo errorDomain], ERROR_NOT_FOUND, @"object %@ not found", theBlobKey);
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
    if (sb == nil) {
        return nil;
    }

    NSString *mimeType = [sb mimeType];
    NSString *downloadName = [sb downloadName];
    NSData *encrypted = [sb slurp:error];
    [sb release];
    sb = nil;
    if (encrypted == nil) {
        return nil;
    }
    NSData *data = [encrypted decryptWithCryptoKey:([theBlobKey stretchEncryptionKey] ? stretchedCryptoKey : cryptoKey) error:error];
    if (data == nil) {
        return nil;
    }
    id <InputStream> blobIS = [[DataInputStream alloc] initWithData:data];
    sb = [[ServerBlob alloc] initWithInputStream:blobIS mimeType:mimeType downloadName:downloadName];
    [blobIS release];
    return sb;
}
- (BOOL)containsPackedBlob:(BOOL *)contains forBlobKey:(BlobKey *)theBlobKey packSetName:(NSString **)packSetName packSHA1:(NSString **)packSHA1 error:(NSError **)error {
    if (![blobsPackSet containsBlob:contains forSHA1:[theBlobKey sha1] packSHA1:packSHA1 error:error]) {
        return NO;
    }
    if (*contains) {
        *packSetName = [blobsPackSet packSetName];
        return YES;
    }
    
    if (![treesPackSet containsBlob:contains forSHA1:[theBlobKey sha1] packSHA1:packSHA1 error:error]) {
        return NO;
    }
    if (*contains) {
        *packSetName = [treesPackSet packSetName];
    }
    return YES;
}


#pragma mark NSObject
- (NSString *)description {
    return [NSString stringWithFormat:@"<ArqRepo: bucketUUID=%@>", bucketUUID];
}
@end
