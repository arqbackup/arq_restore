//
//  BucketExclude.h
//
//  Created by Stefan Reitshamer on 4/26/11.
//  Copyright 2011 Haystack Software. All rights reserved.
//


@class DictNode;

enum {
    kBucketExcludeTypeFileNameIs = 1,
    kBucketExcludeTypeFileNameContains = 2,
    kBucketExcludeTypeFileNameStartsWith = 3,
    kBucketExcludeTypeFileNameEndsWith = 4,
    kBucketExcludeTypePathMatchesRegex = 5
};
typedef UInt32 BucketExcludeType;

@interface BucketExclude : NSObject <NSCopying> {
    BucketExcludeType type;
    NSString *text;
}
- (id)initWithType:(BucketExcludeType)theType text:(NSString *)theText;
- (id)initWithPlist:(DictNode *)thePlist;
- (DictNode *)toPlist;
- (BOOL)matchesFullPath:(NSString *)thePath filename:(NSString *)theFilename;

@property (readonly) BucketExcludeType type;
@property (readonly, copy) NSString *text;
@end
