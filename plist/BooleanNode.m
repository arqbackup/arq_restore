//
//  BooleanNode.m
//  Backup
//
//  Created by Stefan Reitshamer on 4/13/09.
//  Copyright 2009 PhotoMinds LLC. All rights reserved.
//

#import "PListNodeType.h"
#import "BooleanNode.h"


@implementation BooleanNode
- (id)initWithBoolean:(BOOL)b {
	if (self = [super init]) {
		value = b;
	}
	return self;
}
- (BOOL)booleanValue {
	return value;
}


#pragma mark PListNode protocol

- (int)type {
	return PLN_BOOLEAN;
}


#pragma mark NSObject protocol

- (NSString *)description {
    return [NSString stringWithFormat:@"<BooleanNode 0x%x %@>", self, (value ? @"YES" : @"NO")];
}
@end
