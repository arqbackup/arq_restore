//
//  BinarySHA1.m
//
//  Created by Stefan Reitshamer on 12/30/09.
//  Copyright 2009 Haystack Software. All rights reserved.
//

#import "BinarySHA1.h"


@implementation BinarySHA1
+ (NSComparisonResult)compare:(const void *)a to:(const void *)b {
    unsigned char *left = (unsigned char *)a;
    unsigned char *right = (unsigned char *)b;
    for (int i = 0; i < 20; i++) {
        if (left[i] < right[i]) {
            return NSOrderedAscending;
        }
        if (left[i] > right[i]) {
            return NSOrderedDescending;
        }
    }
    return NSOrderedSame;
}
@end
