//
//  BucketExcludeSet.m
//
//  Created by Stefan Reitshamer on 4/27/11.
//  Copyright 2011 Haystack Software. All rights reserved.
//

#import "BucketExcludeSet.h"
#import "BucketExclude.h"
#import "DictNode.h"
#import "ArrayNode.h"

@interface BucketExcludeSet (internal)
- (id)initWithBucketExcludes:(NSMutableArray *)theBucketExcludes;
@end

@implementation BucketExcludeSet
- (id)init {
    if (self = [super init]) {
        bucketExcludes = [[NSMutableArray alloc] init];
    }
    return self;
}
- (void)dealloc {
    [bucketExcludes release];
    [super dealloc];
}

- (void)loadFromPlist:(DictNode *)thePlist localPath:(NSString *)theLocalPath {
    [bucketExcludes removeAllObjects];
    if ([thePlist containsKey:@"Conditions"]) {
        ArrayNode *conditions = [thePlist arrayNodeForKey:@"Conditions"];
        for (NSUInteger index = 0; index < [conditions size]; index++) {
            DictNode *condition = [conditions dictNodeAtIndex:(int)index];
            NSString *matchText = [[condition stringNodeForKey:@"MatchText"] stringValue];
            NSString *escapedLocalPath = [theLocalPath stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
            escapedLocalPath = [escapedLocalPath stringByReplacingOccurrencesOfString:@"^" withString:@"\\^"];
            escapedLocalPath = [escapedLocalPath stringByReplacingOccurrencesOfString:@"$" withString:@"\\$"];
            escapedLocalPath = [escapedLocalPath stringByReplacingOccurrencesOfString:@"." withString:@"\\."];
            escapedLocalPath = [escapedLocalPath stringByReplacingOccurrencesOfString:@"*" withString:@"\\*"];
            escapedLocalPath = [escapedLocalPath stringByReplacingOccurrencesOfString:@"|" withString:@"\\|"];
            escapedLocalPath = [escapedLocalPath stringByReplacingOccurrencesOfString:@"+" withString:@"\\+"];
            escapedLocalPath = [escapedLocalPath stringByReplacingOccurrencesOfString:@"?" withString:@"\\?"];
            escapedLocalPath = [escapedLocalPath stringByReplacingOccurrencesOfString:@"{" withString:@"\\{"];
            escapedLocalPath = [escapedLocalPath stringByReplacingOccurrencesOfString:@"(" withString:@"\\("];
            NSString *escapedMatchText = [matchText stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
            escapedMatchText = [escapedMatchText stringByReplacingOccurrencesOfString:@"^" withString:@"\\^"];
            escapedMatchText = [escapedMatchText stringByReplacingOccurrencesOfString:@"$" withString:@"\\$"];
            escapedMatchText = [escapedMatchText stringByReplacingOccurrencesOfString:@"." withString:@"\\."];
            escapedMatchText = [escapedMatchText stringByReplacingOccurrencesOfString:@"*" withString:@"\\*"];
            escapedMatchText = [escapedMatchText stringByReplacingOccurrencesOfString:@"|" withString:@"\\|"];
            escapedMatchText = [escapedMatchText stringByReplacingOccurrencesOfString:@"+" withString:@"\\+"];
            escapedMatchText = [escapedMatchText stringByReplacingOccurrencesOfString:@"?" withString:@"\\?"];
            escapedMatchText = [escapedMatchText stringByReplacingOccurrencesOfString:@"{" withString:@"\\{"];
            escapedMatchText = [escapedMatchText stringByReplacingOccurrencesOfString:@"(" withString:@"\\("];
            NSString *regex = nil;
            int matchTypeId = [[condition integerNodeForKey:@"MatchTypeId"] intValue];
            int objectTypeId = [[condition integerNodeForKey:@"ObjectTypeId"] intValue];
            BucketExcludeType excludeType = 0;
            switch (matchTypeId) {
                case 2:
                    excludeType = kBucketExcludeTypeFileNameContains;
                    regex = [NSString stringWithFormat:@"^%@.*/[^/]*%@[^/]*$", escapedLocalPath, escapedMatchText];
                    break;
                case 4:
                    excludeType = kBucketExcludeTypeFileNameIs;
                    regex = [NSString stringWithFormat:@"^%@.*/%@$", escapedLocalPath, escapedMatchText];
                    break;
                case 6:
                    excludeType = kBucketExcludeTypeFileNameStartsWith;
                    regex = [NSString stringWithFormat:@"^%@.*/%@[^/]*$", escapedLocalPath, escapedMatchText];
                    break;
                case 7:
                    excludeType = kBucketExcludeTypeFileNameEndsWith;
                    regex = [NSString stringWithFormat:@"^%@/.*%@$", escapedLocalPath, escapedMatchText];
                    break;
            }
            if (objectTypeId == 2) {
                excludeType = kBucketExcludeTypePathMatchesRegex;
                matchText = regex;
            }
            BucketExclude *be = [[[BucketExclude alloc] initWithType:excludeType text:matchText] autorelease];
            [bucketExcludes addObject:be];
        }
    } else {
        ArrayNode *excludes = [thePlist arrayNodeForKey:@"excludes"];
        for (NSUInteger index = 0; index < [excludes size]; index++) {
            BucketExclude *bce = [[[BucketExclude alloc] initWithPlist:[excludes dictNodeAtIndex:(int)index]] autorelease];
            [bucketExcludes addObject:bce];
        }
    }
}
- (DictNode *)toPlist {
    DictNode *plist = [[[DictNode alloc] init] autorelease];
    ArrayNode *array = [[[ArrayNode alloc] init] autorelease];
    [plist put:array forKey:@"excludes"];
    for (BucketExclude *bce in bucketExcludes) {
        [array add:[bce toPlist]];
    }
    return plist;
}
- (NSArray *)bucketExcludes {
    return bucketExcludes;
}
- (BOOL)containsExcludeWithType:(BucketExcludeType)theType text:(NSString *)theText {
    for (BucketExclude *bce in bucketExcludes) {
        if (bce.type == theType && [bce.text isEqualToString:theText]) {
            return YES;
        }
    }
    return NO;
}
- (void)addExcludeWithType:(BucketExcludeType)theType text:(NSString *)theText {
    if (![self containsExcludeWithType:theType text:theText]) {
        BucketExclude *bce = [[[BucketExclude alloc] initWithType:theType text:theText] autorelease];
        [bucketExcludes addObject:bce];
    }
}
- (void)removeExcludeWithType:(BucketExcludeType)theType text:(NSString *)theText {
    BucketExclude *found = nil;
    for (BucketExclude *bce in bucketExcludes) {
        if (bce.type == theType && [bce.text isEqualToString:theText]) {
            found = bce;
            break;
        }
    }
    if (found != nil) {
        [bucketExcludes removeObject:found];
    }
}
- (void)setExcludes:(NSArray *)theBucketExcludes {
    [bucketExcludes setArray:theBucketExcludes];
}
- (BOOL)removeEmptyExcludes {
    NSMutableSet *itemsToRemove = [NSMutableSet set];
    for (BucketExclude *bce in bucketExcludes) {
        if ([bce.text length] == 0) {
            [itemsToRemove addObject:bce];
        }
    }
    [bucketExcludes removeObjectsInArray:[itemsToRemove allObjects]];
    return ([itemsToRemove count] > 0);
}
- (BOOL)matchesFullPath:(NSString *)thePath filename:(NSString *)theFilename {
    for (BucketExclude *bce in bucketExcludes) {
        if ([bce matchesFullPath:thePath filename:theFilename]) {
            return YES;
        }
    }
    return NO;
}
- (void)clearExcludes {
    [bucketExcludes removeAllObjects];
}


#pragma mark NSCopying
- (id)copyWithZone:(NSZone *)zone {
    NSMutableArray *excludesCopy = [[NSMutableArray alloc] initWithArray:bucketExcludes copyItems:YES];
    BucketExcludeSet *ret = [[BucketExcludeSet alloc] initWithBucketExcludes:excludesCopy];
    [excludesCopy release];
    return ret;
}
@end

@implementation BucketExcludeSet (internal)
- (id)initWithBucketExcludes:(NSMutableArray *)theBucketExcludes {
    if (self = [super init]) {
        bucketExcludes = [theBucketExcludes retain];
    }
    return self;
}
@end
