//
//  PackIndexEntry.h
//  Arq
//
//  Created by Stefan Reitshamer on 12/30/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//




@interface PackIndexEntry : NSObject {
    NSString *packSHA1;
    unsigned long long offset;
    unsigned long long dataLength;
    NSString *objectSHA1;
}
- (id)initWithPackSHA1:(NSString *)thePackSHA1 offset:(unsigned long long)theOffset dataLength:(unsigned long long)theDataLength objectSHA1:(NSString *)theObjectSHA1;
- (NSString *)packSHA1;
- (unsigned long long)offset;
- (unsigned long long)dataLength;
- (NSString *)objectSHA1;
@end
