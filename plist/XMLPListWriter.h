//
//  XMLPListWriter.h
//  Backup
//
//  Created by Stefan Reitshamer on 4/13/09.
//  Copyright 2009 PhotoMinds LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>
@class DictNode;

@interface XMLPListWriter : NSObject {
    NSMutableData *data;
}
- (id)initWithMutableData:(NSMutableData *)theData;
- (void)write:(DictNode *)plist;
@end
