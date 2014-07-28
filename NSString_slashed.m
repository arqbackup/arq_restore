//
//  NSString_slashed.m
//  Arq
//
//  Created by Stefan Reitshamer on 4/22/11.
//  Copyright 2011 Haystack Software. All rights reserved.
//

#import "NSString_slashed.h"

@implementation NSString (slashed)
- (NSString *)slashed {
    if ([self isEqualToString:@"/"]) {
        return self;
    }
    return [self stringByAppendingString:@"/"];
}
@end
