//
//  PackIndexEntry.m
//  Arq
//
//  Created by Stefan Reitshamer on 12/30/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "PackIndexEntry.h"


@implementation PackIndexEntry
- (id)initWithPackSHA1:(NSString *)thePackSHA1 offset:(unsigned long long)theOffset dataLength:(unsigned long long)theDataLength objectSHA1:(NSString *)theObjectSHA1 {
    if (self = [super init]) {
        packSHA1 = [thePackSHA1 copy];
        offset = theOffset;
        dataLength = theDataLength;
        objectSHA1 = [theObjectSHA1 copy];
    }
    return self;
}
- (void)dealloc {
    [packSHA1 release];
    [objectSHA1 release];
    [super dealloc];
}
- (NSString *)packSHA1 {
    return packSHA1;
}
- (unsigned long long)offset {
    return offset;
}
- (unsigned long long)dataLength {
    return dataLength;
}
- (NSString *)objectSHA1 {
    return objectSHA1;
}

#pragma mark NSObject
- (NSString *)description {
    return [NSString stringWithFormat:@"<PackIndexEntry: packSHA1=%@ offset=%qu dataLength=%qu objectSHA1=%@>", packSHA1, offset, dataLength, objectSHA1];
}
@end
