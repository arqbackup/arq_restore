//
//  StringNode.m
//  Backup
//
//  Created by Stefan Reitshamer on 4/13/09.
//  Copyright 2009 PhotoMinds LLC. All rights reserved.
//

#import "PListNodeType.h"
#import "StringNode.h"


@implementation StringNode
- (id)initWithString:(NSString *)theValue {
	if (self = [super init]) {
		value = [theValue copy];
	}
	return self;
}
- (void)dealloc {
	[value release];
	[super dealloc];
}
- (NSString *)stringValue {
	return value;
}


#pragma mark PListNode protocol

- (int)type {
	return PLN_STRING;
}



#pragma mark NSObject protocol

- (NSString *)description {
    return [NSString stringWithFormat:@"<StringNode 0x%x \"%@\">", self, value];
}
@end
