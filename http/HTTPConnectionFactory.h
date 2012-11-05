//
//  HTTPConnectionFactory.h
//  Arq
//
//  Created by Stefan Reitshamer on 3/15/12.
//  Copyright 2012 __MyCompanyName__. All rights reserved.
//


@protocol HTTPConnection;
@protocol HTTPConnectionDelegate;
@class HTTPTimeoutSetting;


@interface HTTPConnectionFactory : NSObject {
    NSTimeInterval maxConnectionLifetime;
    NSLock *lock;
    NSMutableDictionary *connectionMapsByThreadId;
}

+ (HTTPConnectionFactory *)theFactory;
- (id <HTTPConnection>)newHTTPConnectionToURL:(NSURL *)theURL
                                       method:(NSString *)theMethod 
                           httpTimeoutSetting:(HTTPTimeoutSetting *)theHTTPTimeoutSetting
                       httpConnectionDelegate:(id <HTTPConnectionDelegate>)theHTTPConnectionDelegate;

@end
