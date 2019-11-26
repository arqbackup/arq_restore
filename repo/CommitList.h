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




@class Repo;
@class Commit;
@class BlobKey;

@interface BlobKeyCommitPair : NSObject {
    BlobKey *blobKey;
    Commit *commit;
}
+ (BlobKeyCommitPair *)pairWithBlobKey:(BlobKey *)theBlobKey commit:(Commit *)theCommit;
- (id)initWithBlobKey:(BlobKey *)theBlobKey commit:(Commit *)theCommit;
- (BlobKey *)blobKey;
- (Commit *)commit;
@end

@interface CommitList : NSObject {
    NSUInteger index;
    NSMutableArray *reverseChronoPairs;
    BOOL hadMissingBlobs;
}
- (id)initWithHeadBlobKey:(BlobKey *)headBlobKey repo:(Repo *)repo error:(NSError **)error;
- (NSArray *)commitBlobKeys;
- (NSArray *)reverseChronoCommitBlobKeysBetween:(NSDate *)from and:(NSDate *)to;
- (BlobKey *)newestCommitBlobKeyBetween:(NSDate *)from and:(NSDate *)to;
- (NSDate *)oldestCommitDate;
- (BlobKey *)newestBlobKey;
- (NSUInteger)count;
- (NSUInteger)index;
- (NSArray *)blobKeyCommitPairs;
- (BlobKeyCommitPair *)blobKeyCommitPairAtIndex:(NSUInteger)index;
- (void)incrementIndex;
- (void)decrementIndex;
- (NSArray *)reverseChronoCommitBlobKeysFromZeroToIndex;
- (void)dropCommitBlobKeyAndAllOlder:(BlobKey *)theCommitBlobKey;
- (BOOL)hadMissingBlobs;
@end
