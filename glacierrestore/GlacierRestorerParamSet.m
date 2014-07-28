//
//  GlacierRestorerParamSet.m
//  Arq
//
//  Created by Stefan Reitshamer on 5/29/13.
//  Copyright (c) 2013 Stefan Reitshamer. All rights reserved.
//

#import "GlacierRestorerParamSet.h"
#import "AWSRegion.h"
#import "BlobKey.h"
#import "StringIO.h"
#import "IntegerIO.h"
#import "BlobKeyIO.h"
#import "BooleanIO.h"
#import "DataIO.h"
#import "Tree.h"
#import "DoubleIO.h"
#import "Bucket.h"


@implementation GlacierRestorerParamSet
@synthesize bucket;
@synthesize encryptionPassword;
@synthesize downloadBytesPerSecond;
@synthesize commitBlobKey;
@synthesize rootItemName;
@synthesize treeBlobKey;
@synthesize nodeName;
@synthesize targetUID;
@synthesize targetGID;
@synthesize useTargetUIDAndGID;
@synthesize destinationPath;
@synthesize logLevel;


- (id)initWithBucket:(Bucket *)theBucket
  encryptionPassword:(NSString *)theEncryptionPassword
downloadBytesPerSecond:(double)theDownloadBytesPerSecond
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
            logLevel:(int)theLogLevel {
    if (self = [super init]) {
        bucket = [theBucket retain];
        encryptionPassword = [theEncryptionPassword retain];
        downloadBytesPerSecond = theDownloadBytesPerSecond;
        commitBlobKey = [theCommitBlobKey retain];
        rootItemName = [theRootItemName retain];
        treeVersion = theTreeVersion;
        treeIsCompressed = theTreeIsCompressed;
        treeBlobKey = [theTreeBlobKey retain];
        nodeName = [theNodeName retain];
        targetUID = theTargetUID;
        targetGID = theTargetGID;
        useTargetUIDAndGID = theUseTargetUIDAndGID;
        destinationPath = [theDestination retain];
        logLevel = theLogLevel;
    }
    return self;
}
- (void)dealloc {
    [bucket release];
    [encryptionPassword release];
    [commitBlobKey release];
    [rootItemName release];
    [treeBlobKey release];
    [nodeName release];
    [destinationPath release];
    [super dealloc];
}
@end
