//
//  HTTPTimeoutSetting.m
//  Arq
//
//  Created by Stefan Reitshamer on 4/6/12.
//  Copyright 2012 __MyCompanyName__. All rights reserved.
//

#import "HTTPTimeoutSetting.h"

#define DEFAULT_TIMEOUT_SECONDS 30.0

@implementation HTTPTimeoutSetting
- (id)init {
    self = [super init];
    return self;
}
- (id)initWithTimeoutSeconds:(NSTimeInterval)theTimeoutSeconds {
    if (self = [super init]) {
        timeoutSeconds = theTimeoutSeconds;
    }
    return self;
}
- (NSTimeInterval)timeoutSeconds {
    NSTimeInterval ret = timeoutSeconds;
    if (ret == 0) {
        [[NSUserDefaults standardUserDefaults] synchronize];
        ret = (NSTimeInterval)[[NSUserDefaults standardUserDefaults] doubleForKey:@"HTTPTimeoutSeconds"];
    }
    if (ret == 0) {
        ret = DEFAULT_TIMEOUT_SECONDS;
    }
    return ret;
}
@end
