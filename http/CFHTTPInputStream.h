//
//  CFHTTPInputStream.h
//  Arq
//
//  Created by Stefan Reitshamer on 3/16/12.
//  Copyright 2012 __MyCompanyName__. All rights reserved.
//


@class CFHTTPConnection;
@protocol HTTPConnectionDelegate;
@class NetMonitor;


@interface CFHTTPInputStream : NSObject {
    CFHTTPConnection *conn;
    NSInputStream *inputStream;
    id <HTTPConnectionDelegate> httpConnectionDelegate;
    int throttleType;
    int throttleKBPS;
    NSTimeInterval lastReceivedTime;
    NSUInteger lastReceivedLength;
    NSUInteger totalReceivedLength;
    NetMonitor *netMonitor;
}
- (id)initWithCFHTTPConnection:(CFHTTPConnection *)theConn data:(NSData *)theData httpConnectionDelegate:(id <HTTPConnectionDelegate>)theHTTPConnectionDelegate;

@end
