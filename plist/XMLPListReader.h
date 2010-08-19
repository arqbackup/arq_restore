//
//  XMLPListReader.h
//  Backup
//
//  Created by Stefan Reitshamer on 4/13/09.
//  Copyright 2009 PhotoMinds LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>
@class DictNode;

@interface XMLPListReader : NSObject {
	NSData *data;
}
- (id)initWithData:(NSData *)theData;
- (DictNode *)read:(NSError **)error;
@end
