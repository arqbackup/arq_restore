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


@class AWSRegion;
@class BlobKey;
@class Bucket;


@interface GlacierRestorerParamSet : NSObject {
    Bucket *bucket;
    NSString *encryptionPassword;
    double downloadBytesPerSecond;
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
            logLevel:(int)theLogLevel;

@property (readonly, retain) Bucket *bucket;
@property (readonly, retain) NSString *encryptionPassword;
@property (readonly) double downloadBytesPerSecond;
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
