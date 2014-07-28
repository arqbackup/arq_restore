//
//  HTTPThrottle.m
//  Arq
//
//  Created by Stefan Reitshamer on 6/5/13.
//  Copyright (c) 2013 Stefan Reitshamer. All rights reserved.
//

#import "HTTPThrottle.h"


@implementation HTTPThrottle
- (id)init {
    if (self = [super init]) {
        throttleType = HTTP_THROTTLE_TYPE_NONE;
    }
    return self;
}
- (id)initWithType:(HTTPThrottleType)theType kbps:(NSUInteger)theKBPS {
    if (self = [super init]) {
        throttleType = theType;
        throttleKBPS = theKBPS;
    }
    return self;
}

- (HTTPThrottleType)throttleType {
    return throttleType;
}
- (NSUInteger)throttleKBPS {
    return throttleKBPS;
}
@end
