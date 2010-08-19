//
//  PackIndexWriter.h
//  Arq
//
//  Created by Stefan Reitshamer on 3/3/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
@class DiskPack;

@interface PackIndexWriter : NSObject {
    DiskPack *diskPack;
    NSString *destination;
}
- (id)initWithPack:(DiskPack *)theDiskPack destination:(NSString *)theDestination;
- (BOOL)writeIndex:(NSError **)error;
@end
