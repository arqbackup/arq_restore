//
//  PackIndexEntry.m
//  Arq
//
//  Created by Stefan Reitshamer on 12/30/09.
//  Copyright 2009 Haystack Software. All rights reserved.
//

#import "PackIndexEntry.h"
#import "PackId.h"


@implementation PackIndexEntry
- (id)initWithPackId:(PackId *)thePackId offset:(unsigned long long)theOffset dataLength:(unsigned long long)theDataLength objectSHA1:(NSString *)theObjectSHA1 {
    if (self = [super init]) {
        packId = [thePackId retain];
        offset = theOffset;
        dataLength = theDataLength;
        objectSHA1 = [theObjectSHA1 copy];
    }
    return self;
}
- (void)dealloc {
    [packId release];
    [objectSHA1 release];
    [super dealloc];
}
- (PackId *)packId {
    return packId;
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
    return [NSString stringWithFormat:@"<PackIndexEntry: packId=%@ offset=%qu dataLength=%qu objectSHA1=%@>", packId, offset, dataLength, objectSHA1];
}


#pragma mark NSCopying
- (id)copyWithZone:(NSZone *)zone {
    return [[PackIndexEntry alloc] initWithPackId:packId
                                           offset:offset
                                       dataLength:dataLength
                                       objectSHA1:objectSHA1];
}
@end
