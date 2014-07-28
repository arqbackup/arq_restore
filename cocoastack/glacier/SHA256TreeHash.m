//
//  SHA256TreeHash.m
//  Arq
//
//  Created by Stefan Reitshamer on 9/12/12.
//
//

#import "SHA256TreeHash.h"
#import "SHA256Hash.h"
#import "NSString_extra.h"


#define ONE_MB (1024 * 1024)

@implementation SHA256TreeHash
+ (NSData *)treeHashOfData:(NSData *)data {
    if ([data length] == 0) {
        return [SHA256Hash hashData:data];
    }
    
    NSMutableArray *hashes = [NSMutableArray array];
    
    const unsigned char *bytes = (const unsigned char *)[data bytes];
    NSUInteger length = [data length];
    NSUInteger index = 0;
    while (index < length) {
        NSUInteger toRead = (index + ONE_MB) > length ? (length - index) : ONE_MB;
        NSData *hash = [SHA256Hash hashBytes:(bytes + index) length:toRead];
        [hashes addObject:hash];
        index += toRead;
    }
    
    while ([hashes count] > 1) {
        NSMutableArray *condensed = [NSMutableArray array];
        for (NSUInteger index = 0; index < [hashes count] / 2; index++) {
            NSMutableData *combined = [NSMutableData dataWithData:[hashes objectAtIndex:(index * 2)]];
            [combined appendData:[hashes objectAtIndex:(index * 2 + 1)]];
            [condensed addObject:[SHA256Hash hashData:combined]];
        }
        if ([hashes count] % 2 == 1) {
            [condensed addObject:[hashes objectAtIndex:([hashes count] - 1)]];
        }
        [hashes setArray:condensed];
    }
    return [hashes objectAtIndex:0];
}
@end
