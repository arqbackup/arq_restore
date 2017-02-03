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



#import "CommitList.h"
#import "Commit.h"
#import "Repo.h"
#import "Bucket.h"


@implementation BlobKeyCommitPair
+ (BlobKeyCommitPair *)pairWithBlobKey:(BlobKey *)theBlobKey commit:(Commit *)theCommit {
    return [[[BlobKeyCommitPair alloc] initWithBlobKey:theBlobKey commit:theCommit] autorelease];
}
- (id)initWithBlobKey:(BlobKey *)theBlobKey commit:(Commit *)theCommit {
    if (self = [super init]) {
        blobKey = [theBlobKey retain];
        commit = [theCommit retain];
    }
    return self;
}
- (void)dealloc {
    [blobKey release];
    [commit release];
    [super dealloc];
}
- (BlobKey *)blobKey {
    return blobKey;
}
- (Commit *)commit {
    return commit;
}

#pragma mark NSObject
- (NSString *)description {
    return [NSString stringWithFormat:@"<BlobKeyCommitPair: blobKey=%@ commit=%@>", blobKey, commit];
}
@end

@implementation CommitList
- (id)initWithHeadBlobKey:(BlobKey *)headBlobKey repo:(Repo *)repo error:(NSError **)error {
    if (self = [super init]) {
        reverseChronoPairs = [[NSMutableArray alloc] init];
        BlobKey *blobKey = headBlobKey;
        while (blobKey != nil) {
            NSError *myError = nil;
            Commit *commit = [repo commitForBlobKey:blobKey error:&myError];
            if (commit == nil) {
                if (blobKey == headBlobKey || ![myError isErrorWithDomain:[repo errorDomain] code:ERROR_NOT_FOUND]) {
                    SETERRORFROMMYERROR;
                    [self release];
                    return nil;
                } else {
                    HSLogInfo(@"commit %@ not found! skipping it (and therefore all before it)", headBlobKey);
                    break;
                }
            }
            [reverseChronoPairs addObject:[BlobKeyCommitPair pairWithBlobKey:blobKey commit:commit]];
            blobKey = [commit parentCommitBlobKey];
        }
        HSLogDetail(@"found %ld commits for bucket %@ (%@)", [reverseChronoPairs count], [[repo bucket] bucketUUID], [[repo bucket] bucketName]);
    }
    return self;
}
- (void)dealloc {
    [reverseChronoPairs release];
    [super dealloc];
}
- (NSArray *)commitBlobKeys {
    NSMutableArray *array = [[[NSMutableArray alloc] init] autorelease];
    for (BlobKeyCommitPair *pair in reverseChronoPairs) {
        [array addObject:[pair blobKey]];
    }
    return array;
}
- (NSArray *)reverseChronoCommitBlobKeysBetween:(NSDate *)from and:(NSDate *)to {
    NSMutableArray *array = [[[NSMutableArray alloc] init] autorelease];
    for (BlobKeyCommitPair *pair in reverseChronoPairs) {
        NSDate *creationDate = [[pair commit] creationDate];
        if ([creationDate earlierDate:from] != from) {
            break;
        }
        if ([creationDate earlierDate:to] == creationDate) {
            [array addObject:[pair blobKey]];
        }
    }
    return array;
}
- (NSArray *)reverseChronoCommitBlobKeys {
    return reverseChronoPairs;
}
- (BlobKey *)newestCommitBlobKeyBetween:(NSDate *)from and:(NSDate *)to {
    BlobKeyCommitPair *foundPair = nil;
    for (BlobKeyCommitPair *pair in reverseChronoPairs) {
        NSDate *creationDate = [[pair commit] creationDate];
        if ([creationDate earlierDate:from] == creationDate) {
            break;
        }
        if ([creationDate earlierDate:to] == creationDate) {
            foundPair = pair;
            break;
        }
    }
//    HSLogDebug(@"newestCommitBlobKeyBetween %@ and %@: blobKey=%@ creationDate=%@", from, to, [foundPair blobKey], [[foundPair commit] creationDate]);
    return [foundPair blobKey];
}
- (NSDate *)oldestCommitDate {
//    HSLogDebug(@"oldestCommitDate = %@", [[[reverseChronoPairs lastObject] commit] creationDate]);
    return [[[reverseChronoPairs lastObject] commit] creationDate];
}
- (BlobKey *)newestBlobKey {
    NSAssert([reverseChronoPairs count] > 0, @"must contain at least 1 commit pair");
    return [[reverseChronoPairs objectAtIndex:0] blobKey];
}
- (NSUInteger)count {
    return [reverseChronoPairs count];
}
- (NSUInteger)index {
    return index;
}
- (NSArray *)blobKeyCommitPairs {
    return reverseChronoPairs;
}
- (BlobKeyCommitPair *)blobKeyCommitPairAtIndex:(NSUInteger)theIndex {
    return [reverseChronoPairs objectAtIndex:theIndex];
}
- (void)incrementIndex {
    index++;
}
- (void)decrementIndex {
    index--;
}
- (NSArray *)reverseChronoCommitBlobKeysFromZeroToIndex {
    NSMutableArray *ret = [NSMutableArray array];
    for (NSUInteger i = 0; i < index; i++) {
        [ret addObject:[reverseChronoPairs objectAtIndex:i]];
    }
    return ret;
}
- (void)dropCommitBlobKeyAndAllOlder:(BlobKey *)theCommitBlobKey {
    for (NSUInteger i = 0; i < index; i++) {
        if ([[[reverseChronoPairs objectAtIndex:i] blobKey] isEqual:theCommitBlobKey]) {
            index = i;
            while ([reverseChronoPairs count] > i) {
                hadMissingBlobs = YES;
                [reverseChronoPairs removeObjectAtIndex:i];
            }
            break;
        }
    }
}
- (BOOL)hadMissingBlobs {
    return hadMissingBlobs;
}
#pragma mark NSObject
- (NSString *)description {
    return [NSString stringWithFormat:@"<CommitList: index=%lu pairs=%@>", (unsigned long)index, reverseChronoPairs];
}
@end
