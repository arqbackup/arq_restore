//
//  URLConnection.h
//  Arq
//
//  Created by Stefan Reitshamer on 5/3/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//


#import "HTTPConnection.h"

@class RFC2616DateFormatter;
@protocol DataTransferDelegate;
@class NetMonitor;
@class HTTPInputStream;


@interface URLConnection : NSObject <HTTPConnection> {
    NSString *method;
    id <DataTransferDelegate> delegate;
    NSMutableURLRequest *mutableURLRequest;
    NSURLConnection *urlConnection;
    NSHTTPURLResponse *httpURLResponse;
    RFC2616DateFormatter *dateFormatter;
    unsigned long long totalSent;

    NSMutableData *responseData;
    NSUInteger responseOffset;
    BOOL errorOccurred;
    NSError *_error;
    NSTimeInterval createTime;
    NSDate *date;
    NetMonitor *netMonitor;
    HTTPInputStream *httpInputStream;
}
+ (NSString *)errorDomain;

- (id)initWithURL:(NSURL *)theURL method:(NSString *)theMethod dataTransferDelegate:(id <DataTransferDelegate>)theDelegate;
@end
