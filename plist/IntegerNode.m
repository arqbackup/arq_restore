//
//  IntegerNode.m
//  Backup
//
//  Created by Stefan Reitshamer on 4/13/09.
//  Copyright 2009 PhotoMinds LLC. All rights reserved.
//

#import "PListNode.h"
#import "PListNodeType.h"
#import "IntegerNode.h"
#import "SetNSError.h"

@implementation IntegerNode
- (id)initWithInt:(int)theValue {
	if (self = [super init]) {
		value = (long long)theValue;
	}
	return self;
}
- (id)initWithString:(NSString *)theValue error:(NSError **)error {
	if (self = [super init]) {
		NSScanner *scanner = [NSScanner scannerWithString:theValue];
		if (![scanner scanLongLong:&value]) {
            SETNSERROR(@"PListErrorDomain", -1, @"string does not contain a long long: %@", theValue);
            [self release];
            self = nil;
		}
	}
	return self;
}
- (id)initWithLongLong:(long long)theValue {
	if (self = [super init]) {
		value = theValue;
	}
	return self;
}
- (int)intValue {
	return (int)value;
}
- (long long)longlongValue {
	return value;
}


#pragma mark PListNode protocol

- (int)type {
	return PLN_INTEGER;
}


#pragma mark NSObject protocol

- (NSString *)description {
    return [NSString stringWithFormat:@"<IntegerNode 0x%x %qi>", self, value];
}

@end
