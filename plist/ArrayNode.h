//
//  ArrayNode.h
//  Backup
//
//  Created by Stefan Reitshamer on 4/13/09.
//  Copyright 2009 PhotoMinds LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "PListNode.h"
@class ArrayNode;
@class BooleanNode;
@class DictNode;
@class IntegerNode;
@class RealNode;
@class StringNode;


@interface ArrayNode : NSObject <PListNode> {
	NSMutableArray *list;
}
- (id)initWithArray:(NSArray *)nodes;
- (NSUInteger)size;
- (int)arrayElementsType;
- (id <PListNode>)objectAtIndex:(int)index;
- (ArrayNode *)arrayNodeAtIndex:(int)index;
- (BooleanNode *)booleanNodeAtIndex:(int)index;
- (DictNode *)dictNodeAtIndex:(int)index;
- (IntegerNode *)integerNodeAtIndex:(int)index;
- (RealNode *)realNodeAtIndex:(int)index;
- (StringNode *)stringNodeAtIndex:(int)index;
- (void)add:(id <PListNode>)node;
- (void)add:(id <PListNode>)node atIndex:(int)index;
@end
