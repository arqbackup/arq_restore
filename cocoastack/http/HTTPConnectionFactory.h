//
//  HTTPConnectionFactory.h
//  Arq
//
//  Created by Stefan Reitshamer on 3/15/12.
//  Copyright 2012 Haystack Software. All rights reserved.
//


@protocol HTTPConnection;
@protocol DataTransferDelegate;


@interface HTTPConnectionFactory : NSObject {
//    NSTimeInterval maxConnectionLifetime;
//    NSLock *lock;
//    NSMutableDictionary *connectionMapsByThreadId;
}

+ (HTTPConnectionFactory *)theFactory;
- (id <HTTPConnection>)newHTTPConnectionToURL:(NSURL *)theURL
                                       method:(NSString *)theMethod
                         dataTransferDelegate:(id <DataTransferDelegate>)theDelegate;
@end
