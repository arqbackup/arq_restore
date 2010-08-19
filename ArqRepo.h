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

@interface ArqRepo : NSObject {
    NSString *bucketUUID;
    NSString *encryptionKey;
    ArqFark *arqFark;
    ArqPackSet *treesPackSet;
    ArqPackSet *blobsPackSet;
}
+ (NSString *)errorDomain;
- (id)initWithS3Service:(S3Service *)theS3 
           s3BucketName:(NSString *)theS3BucketName 
           computerUUID:(NSString *)theComputerUUID
             bucketUUID:(NSString *)theBucketUUID 
          encryptionKey:(NSString *)theEncryptionKey;

- (NSString *)headSHA1:(NSError **)error;
- (Commit *)commitForSHA1:(NSString *)theSHA1 error:(NSError **)error;
- (Tree *)treeForSHA1:(NSString *)theSHA1 error:(NSError **)error;
- (NSData *)blobDataForSHA1:(NSString *)sha1 error:(NSError **)error;
- (NSData *)blobDataForSHA1s:(NSArray *)sha1s error:(NSError **)error;
- (ServerBlob *)newServerBlobForSHA1:(NSString *)sha1 error:(NSError **)error;
@end
