//
//  BooleanNode.h
//  Backup
//
//  Created by Stefan Reitshamer on 4/13/09.
//  Copyright 2009 PhotoMinds LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "PListNode.h"

@interface BooleanNode : NSObject <PListNode> {
	BOOL value;
}
- (id)initWithBoolean:(BOOL)value;
- (BOOL)booleanValue;
@end
