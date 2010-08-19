//
//  RealNode.m
//  Backup
//
//  Created by Stefan Reitshamer on 4/13/09.
//  Copyright 2009 PhotoMinds LLC. All rights reserved.
//

#import "PListNodeType.h"
#import "RealNode.h"
#import "SetNSError.h"

@implementation RealNode
- (id)initWithDouble:(double)theValue {
	if (self = [super init]) {
		value = theValue;
	}
	return self;
}
- (id)initWithString:(NSString *)theValue error:(NSError **)error {
	if (self = [super init]) {
		NSScanner *scanner = [NSScanner scannerWithString:theValue];
		if (![scanner scanDouble:&value]) {
            SETNSERROR(@"PListErrorDomain", -1, @"string does not contain a double: %@", theValue);
            [self release];
            self = nil;
		}
	}
	return self;
}
- (double)doubleValue {
	return value;
}


#pragma mark PListNode protocol

- (int)type {
	return PLN_REAL;
}


#pragma mark NSObject protocol

- (NSString *)description {
    return [NSString stringWithFormat:@"<RealNode 0x%x %f>", self, value];
}
@end
