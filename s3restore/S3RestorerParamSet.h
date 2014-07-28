//
//  S3RestorerParamSet.h
//  Arq
//
//  Created by Stefan Reitshamer on 5/28/13.
//  Copyright (c) 2013 Stefan Reitshamer. All rights reserved.
//

#import "StorageType.h"
@class Bucket;
@class BufferedInputStream;
@class BufferedOutputStream;
@class AWSRegion;
@class BlobKey;

@interface S3RestorerParamSet : NSObject {
    Bucket *bucket;
    NSString *encryptionPassword;
    BlobKey *commitBlobKey;
    NSString *rootItemName;
    int treeVersion;
    BOOL treeIsCompressed;
    BlobKey *treeBlobKey;
    NSString *nodeName;
    uid_t targetUID;
    gid_t targetGID;
    BOOL useTargetUIDAndGID;
    NSString *destinationPath;
    int logLevel;
}

- (id)initWithBucket:(Bucket *)theBucket
  encryptionPassword:(NSString *)theEncryptionPassword
       commitBlobKey:(BlobKey *)theCommitBlobKey
        rootItemName:(NSString *)theRootItemName
         treeVersion:(int32_t)theTreeVersion
    treeIsCompressed:(BOOL)theTreeIsCompressed
         treeBlobKey:(BlobKey *)theTreeBlobKey
            nodeName:(NSString *)theNodeName
           targetUID:(uid_t)theTargetUID
           targetGID:(gid_t)theTargetGID
  useTargetUIDAndGID:(BOOL)theUseTargetUIDAndGID
     destinationPath:(NSString *)theDestination
            logLevel:(int)theLogLevel;

@property (readonly, retain) NSString *arqs3restorerPath;
@property (readonly, retain) Bucket *bucket;
@property (readonly, retain) NSString *encryptionPassword;
@property (readonly, retain) BlobKey *commitBlobKey;
@property (readonly, retain) NSString *rootItemName;
@property (readonly, retain) BlobKey *treeBlobKey;
@property (readonly, retain) NSString *nodeName;
@property (readonly) uid_t targetUID;
@property (readonly) gid_t targetGID;
@property (readonly) BOOL useTargetUIDAndGID;
@property (readonly, retain) NSString *destinationPath;
@property (readonly) int logLevel;

@end
