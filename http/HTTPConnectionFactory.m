//
//  HTTPConnectionFactory.m
//  Arq
//
//  Created by Stefan Reitshamer on 3/15/12.
//  Copyright 2012 __MyCompanyName__. All rights reserved.
//

#import "HTTPConnectionFactory.h"
#import "CFHTTPConnection.h"
#import "URLConnection.h"

#define DEFAULT_MAX_HTTPCONNECTION_LIFETIME_SECONDS (20)
#define CLEANUP_THREAD_SLEEP_SECONDS (5)


@interface ConnectionMap : NSObject {
    NSMutableDictionary *connections;
}
- (CFHTTPConnection *)newConnectionToURL:(NSURL *)theURL 
                                  method:(NSString *)theMethod 
                   maxConnectionLifetime:(NSTimeInterval)theMaxConnectionLifetime
                      httpTimeoutSetting:(HTTPTimeoutSetting *)theHTTPTimeoutSetting 
                  httpConnectionDelegate:(id <HTTPConnectionDelegate>)theDelegate;
- (void)dropUnusableConnections:(NSTimeInterval)theMaxConnectionLifetime;
@end

@implementation ConnectionMap
- (id)init {
    if (self = [super init]) {
        connections = [[NSMutableDictionary alloc] init];
    }
    return self;
}
- (void)dealloc {
    [connections release];
    [super dealloc];
}
- (CFHTTPConnection *)newConnectionToURL:(NSURL *)theURL 
                                  method:(NSString *)theMethod 
                   maxConnectionLifetime:(NSTimeInterval)theMaxConnectionLifetime
                      httpTimeoutSetting:(HTTPTimeoutSetting *)theHTTPTimeoutSetting
                  httpConnectionDelegate:(id <HTTPConnectionDelegate>)theHTTPConnectionDelegate {
    NSString *key = [NSString stringWithFormat:@"%@ %@://%@:%d", theMethod, [theURL scheme], [theURL host], [[theURL port] intValue]];
    CFHTTPConnection *conn = [connections objectForKey:key];
    if (conn != nil) {
        if ([conn isCloseRequested] || (([NSDate timeIntervalSinceReferenceDate] - [conn createTime]) > theMaxConnectionLifetime)) {
            [connections removeObjectForKey:key];
            HSLogTrace(@"removing connection %p", conn);
            conn = nil;
        } else {
            HSLogTrace(@"reusing connection %p", conn);
            conn = [[CFHTTPConnection alloc] initWithURL:theURL method:theMethod httpTimeoutSetting:theHTTPTimeoutSetting httpConnectionDelegate:theHTTPConnectionDelegate previousConnection:conn];
            [connections setObject:conn forKey:key];
        }
    }
    if (conn == nil) {
        HSLogTrace(@"new connection %p", conn);
        conn = [[CFHTTPConnection alloc] initWithURL:theURL method:theMethod httpTimeoutSetting:theHTTPTimeoutSetting httpConnectionDelegate:theHTTPConnectionDelegate];
//        [connections setObject:conn forKey:key];
    }
    return conn;
}

- (void)dropUnusableConnections:(NSTimeInterval)theMaxConnectionLifetime {
    NSMutableArray *keysToDrop = [NSMutableArray array];
    for (NSString *key in [connections allKeys]) {
        CFHTTPConnection *conn = [connections objectForKey:key];
        if ([conn isCloseRequested] || (([NSDate timeIntervalSinceReferenceDate] - [conn createTime]) > theMaxConnectionLifetime)) { // FIXME: Duplicate logic to newConnectionToURL: method
            [keysToDrop addObject:key];
        }
    }
    if ([keysToDrop count] > 0) {
        HSLogTrace(@"dropping %@", keysToDrop);
        [connections removeObjectsForKeys:keysToDrop];
    }
}
@end

static HTTPConnectionFactory *theFactory = nil;

@implementation HTTPConnectionFactory
+ (HTTPConnectionFactory *)theFactory {
    if (theFactory == nil) {
        theFactory = [[super allocWithZone:NULL] init];
    }
    return theFactory;
}

/* Singleton recipe: */
+ (id)allocWithZone:(NSZone *)zone {
    return [[HTTPConnectionFactory theFactory] retain];
}
- (id)copyWithZone:(NSZone *)zone {
    return self;
}

- (id)init {
    if (self = [super init]) {
        lock = [[NSLock alloc] init];
        [lock setName:@"HTTPConnectionFactory lock"];
        connectionMapsByThreadId = [[NSMutableDictionary alloc] init];
        maxConnectionLifetime = DEFAULT_MAX_HTTPCONNECTION_LIFETIME_SECONDS;
        [NSThread detachNewThreadSelector:@selector(dropUnusableConnections) toTarget:self withObject:nil];
    }
    return self;
}
- (void)dealloc {
    [lock release];
    [connectionMapsByThreadId release];
    [super dealloc];
}
- (id <HTTPConnection>)newHTTPConnectionToURL:(NSURL *)theURL method:(NSString *)theMethod httpTimeoutSetting:(HTTPTimeoutSetting *)theHTTPTimeoutSetting httpConnectionDelegate:(id <HTTPConnectionDelegate>)theHTTPConnectionDelegate {
    id <HTTPConnection> ret = nil;
    void *pthreadPtr = pthread_self();
#ifdef __LP64__
    NSNumber *threadID = [NSNumber numberWithUnsignedLongLong:(uint64_t)pthreadPtr];
#else
    NSNumber *threadID = [NSNumber numberWithUnsignedLong:(uint32_t)pthreadPtr];
#endif
    [lock lock];
    ConnectionMap *connMap = [connectionMapsByThreadId objectForKey:threadID];
    if (connMap == nil) {
        connMap = [[ConnectionMap alloc] init];
        [connectionMapsByThreadId setObject:connMap forKey:threadID];
        [connMap release];
    }
    ret = [connMap newConnectionToURL:theURL method:theMethod maxConnectionLifetime:maxConnectionLifetime httpTimeoutSetting:theHTTPTimeoutSetting httpConnectionDelegate:theHTTPConnectionDelegate];
    [lock unlock];
    return ret;
}

#pragma mark cleanup thread
- (void)dropUnusableConnections {
    [self retain];
    for (;;) {
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        [NSThread sleepForTimeInterval:CLEANUP_THREAD_SLEEP_SECONDS];
        [lock lock];
        for (ConnectionMap *connMap in [connectionMapsByThreadId allValues]) {
            @try {
                [connMap dropUnusableConnections:maxConnectionLifetime];
            } @catch(NSException *e) {
                HSLogError(@"unexpected exception in HTTPConnectionFactory cleanup thread: %@", [e description]);
            }
        }
        [lock unlock];
        [pool drain];
    }
}
@end
