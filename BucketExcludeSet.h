//
//  BucketExcludeSet.h
//
//  Created by Stefan Reitshamer on 4/27/11.
//  Copyright 2011 Haystack Software. All rights reserved.
//


#import "BucketExclude.h"
@class DictNode;

@interface BucketExcludeSet : NSObject <NSCopying> {
    NSMutableArray *bucketExcludes;
}
- (void)loadFromPlist:(DictNode *)thePlist localPath:(NSString *)theLocalPath;
- (DictNode *)toPlist;
- (NSArray *)bucketExcludes;
- (BOOL)containsExcludeWithType:(BucketExcludeType)theType text:(NSString *)theText;
- (void)addExcludeWithType:(BucketExcludeType)theType text:(NSString *)theText;
- (void)removeExcludeWithType:(BucketExcludeType)theType text:(NSString *)theText;
- (void)setExcludes:(NSArray *)theBucketExcludes;
- (BOOL)removeEmptyExcludes;
- (BOOL)matchesFullPath:(NSString *)thePath filename:(NSString *)theFilename;
- (void)clearExcludes;
@end
