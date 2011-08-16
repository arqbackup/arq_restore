//
//  NSObject_extra.m
//  Arq
//
//  Created by Stefan Reitshamer on 7/4/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "NSObject_extra.h"


@implementation NSObject (extra)
+ (BOOL)equalObjects:(id)left and:(id)right {
    if (left == nil && right == nil) {
        return YES;
    }
    return [left isEqual:right];
}
@end
