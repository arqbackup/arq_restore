//
//  PackIndex.m
//  Arq
//
//  Created by Stefan Reitshamer on 12/30/13.
//  Copyright (c) 2013 Stefan Reitshamer. All rights reserved.
//

#include <libkern/OSByteOrder.h>
#import "PackIndex.h"
#import "PackIndexEntry.h"
#import "NSString_extra.h"
#import "Fark.h"
#import "StringIO.h"
#import "IntegerIO.h"
#import "DataInputStream.h"
#import "BufferedInputStream.h"


typedef struct index_object {
    uint64_t nbo_offset;
    uint64_t nbo_datalength;
    unsigned char sha1[20];
    unsigned char filler[4];
} index_object;

typedef struct pack_index {
    uint32_t magic_number;
    uint32_t nbo_version;
    uint32_t nbo_fanout[256];
    index_object first_index_object;
} pack_index;


@implementation PackIndex
- (id)initWithPackId:(PackId *)thePackId indexData:(NSData *)theIndexData {
    if (self = [super init]) {
        packId = [thePackId retain];
        indexData = [theIndexData retain];
    }
    return self;
}
- (void)dealloc {
    [packId release];
    [indexData release];
    [super dealloc];
}

- (NSArray *)packIndexEntries:(NSError **)error {
    NSMutableArray *ret = [NSMutableArray array];
    
    if ([indexData length] < sizeof(pack_index)) {
        SETNSERROR([self errorDomain], -1, @"pack index data length %ld is smaller than size of pack_index", (unsigned long)[indexData length]);
        return nil;
    }
    pack_index *the_pack_index = (pack_index *)[indexData bytes];
    uint32_t count = OSSwapBigToHostInt32(the_pack_index->nbo_fanout[255]);
    
//    HSLogDebug(@"count=%d sizeof(pack_index)=%ld sizeof(index_object)=%ld data length=%ld", count, sizeof(pack_index), sizeof(index_object), [indexData length]);
    
    if ([indexData length] < sizeof(pack_index) + (count - 1) * sizeof(index_object)) {
        SETNSERROR([self errorDomain], -1, @"pack index data length %ld is smaller than size of pack_index + index_objects", (unsigned long)[indexData length]);
        return nil;
    }
    index_object *indexObjects = &(the_pack_index->first_index_object);
    NSAutoreleasePool *pool = nil;
    for (uint32_t i = 0; i < count; i++) {
        [pool drain];
        pool = [[NSAutoreleasePool alloc] init];
        uint64_t offset = OSSwapBigToHostInt64(indexObjects[i].nbo_offset);
        uint64_t dataLength = OSSwapBigToHostInt64(indexObjects[i].nbo_datalength);
        NSString *objectSHA1 = [NSString hexStringWithBytes:indexObjects[i].sha1 length:20];
        PackIndexEntry *pie = [[[PackIndexEntry alloc] initWithPackId:packId offset:offset dataLength:dataLength objectSHA1:objectSHA1] autorelease];
        [ret addObject:pie];
    }
    [pool drain];
    pool = nil;
    
    return ret;
}


#pragma mark NSObject
- (NSString *)errorDomain {
    return @"PackIndexErrorDomain";
}
- (NSString *)description {
    return [NSString stringWithFormat:@"<PackIndex: %@>", [packId description]];
}
@end
