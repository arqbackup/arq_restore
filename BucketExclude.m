//
//  BucketExclude.m
//
//  Created by Stefan Reitshamer on 4/26/11.
//  Copyright 2011 Haystack Software. All rights reserved.
//

#import "BucketExclude.h"
#import "DictNode.h"
#import "IntegerNode.h"
#import "StringNode.h"
#import "RegexKitLite.h"

@implementation BucketExclude
@synthesize type, text;

- (id)initWithType:(BucketExcludeType)theType text:(NSString *)theText {
    if (self = [super init]) {
        type = theType;
        text = [theText retain];
    }
    return self;
}
- (id)initWithPlist:(DictNode *)thePlist {
    if (self = [super init]) {
        type = [[thePlist integerNodeForKey:@"type"] intValue];
        text = [[[thePlist stringNodeForKey:@"text"] stringValue] retain];
    }
    return self;
}
- (void)dealloc {
    [text release];
    [super dealloc];
}

- (DictNode *)toPlist {
    DictNode *ret = [[[DictNode alloc] init] autorelease];
    [ret put:[[[IntegerNode alloc] initWithInt:type] autorelease] forKey:@"type"];
    [ret put:[[[StringNode alloc] initWithString:text] autorelease] forKey:@"text"];
    return ret;
}

- (BOOL)matchesFullPath:(NSString *)thePath filename:(NSString *)theFilename {
    switch(type) {
        case kBucketExcludeTypeFileNameIs:
            return [theFilename compare:text options:NSCaseInsensitiveSearch] == NSOrderedSame;
        case kBucketExcludeTypeFileNameContains:
            return [theFilename rangeOfString:text options:NSCaseInsensitiveSearch].location != NSNotFound;
        case kBucketExcludeTypeFileNameStartsWith:
            return [[theFilename lowercaseString] hasPrefix:[text lowercaseString]];
        case kBucketExcludeTypeFileNameEndsWith:
            return [[theFilename lowercaseString] hasSuffix:[text lowercaseString]];
        case kBucketExcludeTypePathMatchesRegex:
            return [thePath isMatchedByRegex:text options:RKLCaseless inRange:NSMakeRange(0, [thePath length]) error:NULL];
    }
    return NO;
}

#pragma mark NSObject
- (NSString *)description {
    NSString *typeDesc = @"";
    switch( type) {
        case kBucketExcludeTypeFileNameIs:
            typeDesc = @"kBucketExcludeTypeFileNameIs";
            break;
        case kBucketExcludeTypeFileNameContains:
            typeDesc = @"kBucketExcludeTypeFileNameContains";
            break;
        case kBucketExcludeTypeFileNameStartsWith:
            typeDesc = @"kBucketExcludeTypeFileNameStartsWith";
            break;
        case kBucketExcludeTypeFileNameEndsWith:
            typeDesc = @"kBucketExcludeTypeFileNameEndsWith";
            break;
        case kBucketExcludeTypePathMatchesRegex:
            typeDesc = @"kBucketExcludeTypePathMatchesRegex";
            break;
    }
    return [NSString stringWithFormat:@"<BucketExclude: type=%@ text=%@>", typeDesc, text];
}


#pragma mark NSCopying
- (id)copyWithZone:(NSZone *)theZone {
    return [[BucketExclude alloc] initWithType:type text:text];
}
@end
