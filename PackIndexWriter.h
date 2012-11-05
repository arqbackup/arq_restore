//
//  PackIndexWriter.h
//  Arq
//
//  Created by Stefan Reitshamer on 3/3/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//


@class DiskPack;

@interface PackIndexWriter : NSObject {
    DiskPack *diskPack;
    NSString *destination;
    uid_t targetUID;
    gid_t targetGID;
}
- (id)initWithPack:(DiskPack *)theDiskPack destination:(NSString *)theDestination
         targetUID:(uid_t)theTargetUID 
         targetGID:(gid_t)theTargetGID;
- (BOOL)writeIndex:(NSError **)error;
@end
