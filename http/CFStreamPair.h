//
//  CFStreamPair.h
//  CFN
//
//  Created by Stefan Reitshamer on 2/25/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "StreamPair.h"
@class CFStreamInputStream;
@class CFStreamOutputStream;

@interface CFStreamPair : NSObject <StreamPair> {
    NSString *description;
    CFStreamInputStream *is;
    CFStreamOutputStream *os;
    NSTimeInterval createTime;
    NSTimeInterval maxLifetime;
    BOOL closeRequested;
    
}
+ (NSString *)errorDomain;
+ (NSError *)NSErrorWithNetworkError:(CFErrorRef)err;
- (id)initWithHost:(NSString *)theHost useSSL:(BOOL)isUseSSL maxLifetime:(NSTimeInterval)theMaxLifetime;

@end
