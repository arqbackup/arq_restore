//
//  PackIndexEntry.h
//  Arq
//
//  Created by Stefan Reitshamer on 12/30/09.
//  Copyright 2009 Haystack Software. All rights reserved.
//

@class PackId;


@interface PackIndexEntry : NSObject <NSCopying> {
    PackId *packId;
    unsigned long long offset;
    unsigned long long dataLength;
    NSString *objectSHA1;
}
- (id)initWithPackId:(PackId *)thePackId offset:(unsigned long long)theOffset dataLength:(unsigned long long)theDataLength objectSHA1:(NSString *)theObjectSHA1;
- (PackId *)packId;
- (unsigned long long)offset;
- (unsigned long long)dataLength;
- (NSString *)objectSHA1;
@end
