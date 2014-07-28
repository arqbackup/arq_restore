//
//  HTTPThrottle.h
//  Arq
//
//  Created by Stefan Reitshamer on 6/5/13.
//  Copyright (c) 2013 Stefan Reitshamer. All rights reserved.
//

typedef enum {
    HTTP_THROTTLE_TYPE_NONE = 0,
    HTTP_THROTTLE_TYPE_AUTOMATIC = 1,
    HTTP_THROTTLE_TYPE_FIXED = 2
} HTTPThrottleType;


@interface HTTPThrottle : NSObject {
    HTTPThrottleType throttleType;
    NSUInteger throttleKBPS;
}
- (id)init;
- (id)initWithType:(HTTPThrottleType)theType kbps:(NSUInteger)theKBPS;

- (HTTPThrottleType)throttleType;
- (NSUInteger)throttleKBPS;

@end
