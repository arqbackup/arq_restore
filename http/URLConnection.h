//
//  URLConnection.h
//  Arq
//
//  Created by Stefan Reitshamer on 5/3/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//


@class RFC2616DateFormatter;
#import "HTTPConnection.h"

#define THROTTLE_NONE 0
#define THROTTLE_AUTOMATIC 1
#define THROTTLE_FIXED 2

@interface URLConnection : NSObject <HTTPConnection> {
    NSString *method;
    id delegate;
    NSMutableURLRequest *mutableURLRequest;
    NSURLConnection *urlConnection;
    NSHTTPURLResponse *httpURLResponse;
    RFC2616DateFormatter *dateFormatter;
    BOOL complete;
    unsigned long long totalSent;
    NSData *receivedData;
    NSUInteger offset;
    NSUInteger totalReceived;
    NSError *_error;
    BOOL responseHasContentLength;
    NSUInteger contentLength;
    NSTimeInterval lastSentTime;
}
+ (NSString *)errorDomain;

- (id)initWithURL:(NSURL *)theURL method:(NSString *)theMethod delegate:(id)theDelegate;
@end

@interface NSObject (URLConnectionDelegate)
- (void)urlConnection:(URLConnection *)theURLConnection sentBytes:(unsigned long long)sent throttleType:(int *)theThrottleType throttleKBPS:(int *)theThrottleKBPS pauseRequested:(BOOL *)isPauseRequested abortRequested:(BOOL *)isAbortRequested;
- (void)urlConnection:(URLConnection *)theURLConnection subtractSentBytes:(unsigned long long)sent;
@end
