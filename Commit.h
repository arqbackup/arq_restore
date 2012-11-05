//
//  Commit.h
//  Backup
//
//  Created by Stefan Reitshamer on 3/21/09.
//  Copyright 2009 PhotoMinds LLC. All rights reserved.
//


#import "Blob.h"
#import "BufferedInputStream.h"
@class BlobKey;

#define CURRENT_COMMIT_VERSION 7

@interface Commit : NSObject {
    int commitVersion;
	NSString *_author;
	NSString *_comment;
	NSMutableSet *_parentCommitBlobKeys;
	BlobKey *_treeBlobKey;
	NSString *_location;
    NSString *_computer;
	BlobKey *_mergeCommonAncestorCommitBlobKey;
	NSDate *_creationDate;
    NSArray *_commitFailedFiles;
    NSData *_bucketXMLData;
}
+ (NSString *)errorDomain;
- (id)initWithCommit:(Commit *)commit parentCommitBlobKey:(BlobKey *)parentCommitBlobKey;

- (id)             initWithAuthor:(NSString *)theAuthor 
                          comment:(NSString *)theComment 
             parentCommitBlobKeys:(NSSet *)theParentCommitBlobKeys 
                      treeBlobKey:(BlobKey *)theTreeBlobKey
                         location:(NSString *)theLocation
 mergeCommonAncestorCommitBlobKey:(BlobKey *)theMergeCommonAncestorCommitBlobKey
                commitFailedFiles:(NSArray *)theCommitFailedFiles
                    bucketXMLData:(NSData *)theBucketXMLData;

- (id)initWithBufferedInputStream:(BufferedInputStream *)is error:(NSError **)error;

@property(readonly,copy) NSString *author;
@property(readonly,copy) NSString *comment;
@property(readonly,copy) BlobKey *treeBlobKey;
@property(readonly,retain) NSSet *parentCommitBlobKeys;
@property(readonly,copy) NSString *location;
@property(readonly,copy) NSString *computer;
@property(readonly,copy) BlobKey *mergeCommonAncestorCommitBlobKey;
@property(readonly,retain) NSDate *creationDate;
@property(readonly,retain) NSArray *commitFailedFiles;
@property(readonly, retain) NSData *bucketXMLData;

- (NSNumber *)isMergeCommit;
- (Blob *)toBlob;

@end
