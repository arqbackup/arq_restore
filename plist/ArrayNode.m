//
//  ArrayNode.m
//  Backup
//
//  Created by Stefan Reitshamer on 4/13/09.
//  Copyright 2009 PhotoMinds LLC. All rights reserved.
//

#import "DictNode.h"
#import "ArrayNode.h"
#import "PListNodeType.h"

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


#pragma mark NSObject protocol

- (NSString *)description {
    return [NSString stringWithFormat:@"<ArrayNode 0x%x %@>", self, [list description]];
}
@end
