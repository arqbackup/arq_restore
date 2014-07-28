//
//  HTTPInputStream.h
//
//  Created by Stefan Reitshamer on 3/16/12.
//  Copyright 2012 Haystack Software. All rights reserved.
//


@protocol HTTPConnection;
@class NetMonitor;
#import "HTTPThrottle.h"


@interface HTTPInputStream : NSObject {
    id <HTTPConnection> conn;
    NSInputStream *inputStream;
    HTTPThrottleType throttleType;
    NSUInteger throttleKBPS;
    NSLock *httpThrottleLock;
    NSTimeInterval lastReceivedTime;
    NSUInteger lastReceivedLength;
    NSUInteger totalReceivedLength;
    NetMonitor *netMonitor;
}
- (id)initWithHTTPConnection:(id <HTTPConnection>)theConn data:(NSData *)theData;
- (void)setHTTPThrottle:(HTTPThrottle *)theHTTPThrottle;
@end
