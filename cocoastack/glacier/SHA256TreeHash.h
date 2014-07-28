//
//  SHA256TreeHash.h
//  Arq
//
//  Created by Stefan Reitshamer on 9/12/12.
//
//


@interface SHA256TreeHash : NSObject
+ (NSData *)treeHashOfData:(NSData *)data;
@end
