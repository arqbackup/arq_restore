//
//  HTTPConnectionDelegate.h
//  Arq
//
//  Created by Stefan Reitshamer on 3/16/12.
//  Copyright 2012 __MyCompanyName__. All rights reserved.
//

@protocol HTTPConnection;

#define THROTTLE_NONE 0
#define THROTTLE_AUTOMATIC 1
#define THROTTLE_FIXED 2

@protocol HTTPConnectionDelegate <NSObject>
- (void)httpConnection:(id <HTTPConnection>)theHTTPConnection sentBytes:(unsigned long long)sent throttleType:(int *)theThrottleType throttleKBPS:(int *)theThrottleKBPS pauseRequested:(BOOL *)isPauseRequested abortRequested:(BOOL *)isAbortRequested;
- (void)httpConnection:(id <HTTPConnection>)theHTTPConnection subtractSentBytes:(unsigned long long)sent;
- (BOOL)abortRequestedForHTTPConnection:(id <HTTPConnection>)theHTTPConnection;
@end
