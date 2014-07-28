//
//  PackIndex.h
//  Arq
//
//  Created by Stefan Reitshamer on 12/30/13.
//  Copyright (c) 2013 Stefan Reitshamer. All rights reserved.
//

@class PackId;
@protocol Fark;

@interface PackIndex : NSObject {
    PackId *packId;
    NSData *indexData;
}
- (id)initWithPackId:(PackId *)thePackId indexData:(NSData *)theIndexData;
- (NSArray *)packIndexEntries:(NSError **)error;
@end
