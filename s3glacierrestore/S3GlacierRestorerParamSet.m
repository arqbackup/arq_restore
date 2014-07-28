/*
 Copyright (c) 2009-2014, Stefan Reitshamer http://www.haystacksoftware.com
 
 All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 
 * Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in the
 documentation and/or other materials provided with the distribution.
 
 * Neither the names of PhotoMinds LLC or Haystack Software, nor the names of
 their contributors may be used to endorse or promote products derived from
 this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
 TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */


#import "S3GlacierRestorerParamSet.h"
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


@implementation S3GlacierRestorerParamSet
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
