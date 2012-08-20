//
//  HTTPTimeoutSetting.h
//  Arq
//
//  Created by Stefan Reitshamer on 4/6/12.
//  Copyright 2012 __MyCompanyName__. All rights reserved.
//


@interface HTTPTimeoutSetting : NSObject {
    NSTimeInterval timeoutSeconds;
}
- (id)init;
- (id)initWithTimeoutSeconds:(NSTimeInterval)theTimeoutSeconds;
- (NSTimeInterval)timeoutSeconds;
@end
