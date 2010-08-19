//
//  RealNode.h
//  Backup
//
//  Created by Stefan Reitshamer on 4/13/09.
//  Copyright 2009 PhotoMinds LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "PListNode.h"

@interface RealNode : NSObject <PListNode> {
	double value;
}
- (id)initWithDouble:(double)value;
- (id)initWithString:(NSString *)theValue error:(NSError **)error;
- (double)doubleValue;
@end
