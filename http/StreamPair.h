//
//  StreamPair.h
//  CFN
//
//  Created by Stefan Reitshamer on 2/25/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "BufferedInputStream.h"
#import "OutputStream.h"

@protocol StreamPair <BufferedInputStream, OutputStream>
- (void)setCloseRequested;
- (BOOL)isUsable;

@end
