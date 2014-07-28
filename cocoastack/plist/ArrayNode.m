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

#import "DictNode.h"
#import "ArrayNode.h"
#import "PListNodeType.h"

@interface ArrayNode (internal)
- (id)initWithList:(NSMutableArray *)list;
- (NSArray *)list;
@end

@implementation ArrayNode
- (id)init {
    if (self = [super init]) {
        list = [[NSMutableArray alloc] init];
    }
    return self;
}
- (id)initWithArray:(NSArray *)nodes {
	if (self = [super init]) {
		list = [[NSMutableArray alloc] initWithArray:nodes];
	}
	return self;
}
- (BOOL)isEqualToArrayNode:(ArrayNode *)other {
    if (self == other) {
        return YES;
    }
    if (![list isEqualToArray:[other list]]) {
        return NO;
    }
    return YES;
}
- (void)dealloc {
	[list release];
	[super dealloc];
}
- (NSUInteger)size {
	return [list count];
}
- (int)arrayElementsType {
	if ([list count] == 0) {
		// Who knows.
		return PLN_STRING;
	}
	id <PListNode> node = [list objectAtIndex:0];
	return [node type];
}
- (id <PListNode>)objectAtIndex:(int)index {
	return [list objectAtIndex:index];
}
- (ArrayNode *)arrayNodeAtIndex:(int)index {
	return [list objectAtIndex:index];
}
- (BooleanNode *)booleanNodeAtIndex:(int)index {
	return [list objectAtIndex:index];
}
- (DictNode *)dictNodeAtIndex:(int)index {
	return [list objectAtIndex:index];
}
- (IntegerNode *)integerNodeAtIndex:(int)index {
	return [list objectAtIndex:index];
}
- (RealNode *)realNodeAtIndex:(int)index {
	return [list objectAtIndex:index];
}
- (StringNode *)stringNodeAtIndex:(int)index {
	return [list objectAtIndex:index];
}
- (void)add:(id <PListNode>)node {
	[list addObject:node];
}
- (void)add:(id <PListNode>)node atIndex:(int)index {
	[list insertObject:node atIndex:index];
}


#pragma mark PListNode protocol

- (int)type {
	return PLN_ARRAY;
}

#pragma mark NSCopying protocol
- (id)copyWithZone:(NSZone *)zone {
    NSMutableArray *listCopy = [[NSMutableArray alloc] initWithArray:list copyItems:YES];
    ArrayNode *ret = [[ArrayNode alloc] initWithList:listCopy];
    [listCopy release];
    return ret;
}

#pragma mark NSObject protocol
- (BOOL)isEqual:(id)other {
    if (other == self) {
        return YES;
    }
    if (other == nil || ![other isKindOfClass:[self class]]) {
        return NO;
    }
    return [self isEqualToArrayNode:other];
}
- (NSUInteger)hash {
    NSUInteger prime = 31;
    NSUInteger result = 1;
    result = prime * result + [list hash];
    return result;
}
- (NSString *)description {
    return [NSString stringWithFormat:@"<ArrayNode %@>", [list description]];
}
@end

@implementation ArrayNode (internal)
- (id)initWithList:(NSMutableArray *)theList {
    if (self = [super init]) {
        list = [theList retain];
    }
    return self;
}
- (NSArray *)list {
    return list;
}
@end
