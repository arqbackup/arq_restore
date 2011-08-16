//
//  ArqRepo.h
//  Arq
//
//  Created by Stefan Reitshamer on 6/23/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
@class S3Service;
@class ArqFark;
@class ArqPackSet;
@class Commit;
@class Tree;
@class ServerBlob;
@class CryptoKey;
@class BlobKey;

@interface ArqRepo : NSObject {
    NSString *bucketUUID;
    ArqFark *arqFark;
    CryptoKey *cryptoKey;
    CryptoKey *stretchedCryptoKey;
    ArqPackSet *treesPackSet;
    ArqPackSet *blobsPackSet;
}
+ (NSString *)errorDomain;
- (id)initWithS3Service:(S3Service *)theS3 
           s3BucketName:(NSString *)theS3BucketName 
           computerUUID:(NSString *)theComputerUUID
             bucketUUID:(NSString *)theBucketUUID 
     encryptionPassword:(NSString *)theEncryptionPassword
                   salt:(NSData *)theEncryptionSalt
                  error:(NSError **)error;

- (NSString *)bucketUUID;
- (BlobKey *)headBlobKey:(NSError **)error;
- (Commit *)commitForBlobKey:(BlobKey *)treeBlobKey error:(NSError **)error;
- (Tree *)treeForBlobKey:(BlobKey *)treeBlobKey error:(NSError **)error;
- (NSData *)blobDataForBlobKey:(BlobKey *)treeBlobKey error:(NSError **)error;
- (ServerBlob *)newServerBlobForBlobKey:(BlobKey *)treeBlobKey error:(NSError **)error;
- (BOOL)containsPackedBlob:(BOOL *)contains forBlobKey:(BlobKey *)theBlobKey packSetName:(NSString **)packSetName packSHA1:(NSString **)packSHA1 error:(NSError **)error;
@end
