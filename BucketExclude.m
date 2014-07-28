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
