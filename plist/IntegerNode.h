//
//  IntegerNode.h
//  Backup
//
//  Created by Stefan Reitshamer on 4/13/09.
//  Copyright 2009 PhotoMinds LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "PListNode.h"

@interface IntegerNode : NSObject <PListNode> {
	long long value;
}
- (id)initWithInt:(int)theValue;
- (id)initWithString:(NSString *)theValue error:(NSError **)error;
- (id)initWithLongLong:(long long)theValue;
- (int)intValue;
- (long long)longlongValue;
@end
