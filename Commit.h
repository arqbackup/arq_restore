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

#define CURRENT_COMMIT_VERSION 9

@interface Commit : NSObject {
    int commitVersion;
	NSString *_author;
	NSString *_comment;
    BlobKey *_parentCommitBlobKey;
	BlobKey *_treeBlobKey;
	NSString *_location;
    NSString *_computer;
	NSDate *_creationDate;
    NSArray *_commitFailedFiles;
    BOOL _hasMissingNodes;
    BOOL _isComplete;
    NSData *_bucketXMLData;
}
+ (NSString *)errorDomain;
- (id)initWithCommit:(Commit *)commit parentCommitBlobKey:(BlobKey *)parentCommitBlobKey;

- (id)             initWithAuthor:(NSString *)theAuthor
                          comment:(NSString *)theComment
              parentCommitBlobKey:(BlobKey *)theParentCommitBlobKey
                      treeBlobKey:(BlobKey *)theTreeBlobKey
                         location:(NSString *)theLocation
                     creationDate:(NSDate *)theCreationDate
                commitFailedFiles:(NSArray *)theCommitFailedFiles
                  hasMissingNodes:(BOOL)theHasMissingNodes
                       isComplete:(BOOL)theIsComplete
                    bucketXMLData:(NSData *)theBucketXMLData;

- (id)initWithBufferedInputStream:(BufferedInputStream *)is error:(NSError **)error;

@property(readonly) int commitVersion;
@property(readonly,copy) NSString *author;
@property(readonly,copy) NSString *comment;
@property(readonly,copy) BlobKey *treeBlobKey;
@property(readonly,retain) BlobKey *parentCommitBlobKey;
@property(readonly,copy) NSString *location;
@property(readonly,copy) NSString *computer;
@property(readonly,retain) NSDate *creationDate;
@property(readonly,retain) NSArray *commitFailedFiles;
@property(readonly) BOOL hasMissingNodes;
@property(readonly) BOOL isComplete;
@property(readonly, retain) NSData *bucketXMLData;

- (NSData *)toData;
@end
