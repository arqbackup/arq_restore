/*
 Copyright (c) 2009-2017, Haystack Software LLC https://www.arqbackup.com
 
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



#import "StandardRestorerParamSet.h"
#import "AWSRegion.h"
#import "BlobKey.h"
#import "StringIO.h"
#import "IntegerIO.h"
#import "BlobKeyIO.h"
#import "BooleanIO.h"
#import "DataIO.h"
#import "Tree.h"
#import "Bucket.h"


@implementation StandardRestorerParamSet
@synthesize bucket;
@synthesize encryptionPassword;
@synthesize commitBlobKey;
@synthesize rootItemName;
@synthesize treeBlobKey;
@synthesize nodeName;
@synthesize targetUID;
@synthesize targetGID;
@synthesize useTargetUIDAndGID;
@synthesize destinationPath;
@synthesize logLevel;


- (id)initWithBufferedInputStream:(BufferedInputStream *)theIS error:(NSError **)error {
    if (self = [super init]) {
        if (![self readFromStream:theIS error:error]) {
            [self release];
            return nil;
        }
    }
    return self;
}
- (id)initWithBucket:(Bucket *)theBucket
  encryptionPassword:(NSString *)theEncryptionPassword
       commitBlobKey:(BlobKey *)theCommitBlobKey
        rootItemName:(NSString *)theRootItemName
         treeVersion:(int32_t)theTreeVersion
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
        commitBlobKey = [theCommitBlobKey retain];
        rootItemName = [theRootItemName retain];
        treeVersion = theTreeVersion;
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

- (BOOL)writeTo:(BufferedOutputStream *)theBOS error:(NSError **)error {
    return [bucket writeTo:theBOS error:error]
    && [StringIO write:encryptionPassword to:theBOS error:error]
    && [BlobKeyIO write:commitBlobKey to:theBOS error:error]
    && [StringIO write:rootItemName to:theBOS error:error]
    && [IntegerIO writeInt32:treeVersion to:theBOS error:error]
    && [IntegerIO writeInt32:(int32_t)[treeBlobKey compressionType] to:theBOS error:error]
    && [BlobKeyIO write:treeBlobKey to:theBOS error:error]
    && [StringIO write:nodeName to:theBOS error:error]
    && [IntegerIO writeInt64:(int64_t)targetUID to:theBOS error:error]
    && [IntegerIO writeInt64:(int64_t)targetGID to:theBOS error:error]
    && [BooleanIO write:useTargetUIDAndGID to:theBOS error:error]
    && [StringIO write:destinationPath to:theBOS error:error]
    && [IntegerIO writeUInt32:(uint32_t)logLevel to:theBOS error:error];
}


#pragma mark internal
- (BOOL)readFromStream:(BufferedInputStream *)theIS error:(NSError **)error {
    bucket = [[Bucket alloc] initWithBufferedInputStream:theIS error:error];
    if (bucket == nil) {
        return NO;
    }
    
    if (![StringIO read:&encryptionPassword from:theIS error:error]) {
        return NO;
    }
    [encryptionPassword retain];
    
    int32_t theTreeVersion = 0;
    int64_t theTargetUID = 0;
    int64_t theTargetGID = 0;
    uint32_t theLogLevel = 0;
    
    if (![BlobKeyIO read:&commitBlobKey from:theIS treeVersion:CURRENT_TREE_VERSION compressionType:BlobKeyCompressionNone error:error]) {
        return NO;
    }
    [commitBlobKey retain];
    if (![StringIO read:&rootItemName from:theIS error:error]) {
        return NO;
    }
    [rootItemName retain];
    if (![IntegerIO readInt32:&theTreeVersion from:theIS error:error]) {
        return NO;
    }
    int32_t treeBlobKeyCompressionType = BlobKeyCompressionNone;
    if (![IntegerIO readInt32:&treeBlobKeyCompressionType from:theIS error:error]) {
        return NO;
    }
    if (![BlobKeyIO read:&treeBlobKey from:theIS treeVersion:theTreeVersion compressionType:(BlobKeyCompressionType)treeBlobKeyCompressionType error:error]) {
        return NO;
    }
    [treeBlobKey retain];
    if (![StringIO read:&nodeName from:theIS error:error]) {
        return NO;
    }
    [nodeName retain];
    if (![IntegerIO readInt64:&theTargetUID from:theIS error:error]) {
        return NO;
    }
    targetUID = (uid_t)theTargetUID;
    
    if (![IntegerIO readInt64:&theTargetGID from:theIS error:error]) {
        return NO;
    }
    targetGID = (gid_t)theTargetGID;
    
    if (![BooleanIO read:&useTargetUIDAndGID from:theIS error:error]) {
        return NO;
    }
    if (![StringIO read:&destinationPath from:theIS error:error]) {
        return NO;
    }
    [destinationPath retain];
    if (![IntegerIO readUInt32:&theLogLevel from:theIS error:error]) {
        return NO;
    }
    logLevel = theLogLevel;
    return YES;
}
@end
