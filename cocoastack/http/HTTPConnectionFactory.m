/*
 Copyright (c) 2009-2014, Stefan Reitshamer http://www.haystacksoftware.com
 
 All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 
 * Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in the
 documentation and/or other materials provided with the distribution.
 
 * Neither the names of PhotoMinds LLC or Haystack Software, nor the names of
 their contributors may be used to endorse or promote products derived from
 this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
 TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */


#import "HTTPConnectionFactory.h"
//#if TARGET_OS_IPHONE > 0
#import "URLConnection.h"
//#else
//#import "CFHTTPConnection.h"
//#endif

//#define DEFAULT_MAX_HTTPCONNECTION_LIFETIME_SECONDS (20)
//#define CLEANUP_THREAD_SLEEP_SECONDS (5)
//
//
//@interface ConnectionMap : NSObject {
//    NSMutableDictionary *connections;
//}
//- (id <HTTPConnection>)newConnectionToURL:(NSURL *)theURL
//                                   method:(NSString *)theMethod
//                    maxConnectionLifetime:(NSTimeInterval)theMaxConnectionLifetime
//                     dataTransferDelegate:(id <DataTransferDelegate>)theDelegate;
//- (void)dropUnusableConnections:(NSTimeInterval)theMaxConnectionLifetime;
//@end
//
//@implementation ConnectionMap
//- (id)init {
//    if (self = [super init]) {
//        connections = [[NSMutableDictionary alloc] init];
//    }
//    return self;
//}
//- (void)dealloc {
//    [connections release];
//    [super dealloc];
//}
//- (id <HTTPConnection>)newConnectionToURL:(NSURL *)theURL 
//                                  method:(NSString *)theMethod 
//                    maxConnectionLifetime:(NSTimeInterval)theMaxConnectionLifetime
//                  dataTransferDelegate:(id <DataTransferDelegate>)theDataTransferDelegate {
//    NSString *key = [NSString stringWithFormat:@"%@ %@://%@:%d", theMethod, [theURL scheme], [theURL host], [[theURL port] intValue]];
//    id <HTTPConnection> conn = [connections objectForKey:key];
//    if (conn != nil) {
//        if ([conn errorOccurred] || (([NSDate timeIntervalSinceReferenceDate] - [conn createTime]) > theMaxConnectionLifetime)) {
//            [connections removeObjectForKey:key];
//            HSLogTrace(@"removing connection %p", conn);
//            conn = nil;
//        } else {
//            HSLogTrace(@"found connection %p", conn);
//            conn = [[URLConnection alloc] initWithURL:theURL method:theMethod dataTransferDelegate:theDataTransferDelegate];
//            [connections setObject:conn forKey:key];
//        }
//    }
//    if (conn == nil) {
//        conn = [[URLConnection alloc] initWithURL:theURL method:theMethod dataTransferDelegate:theDataTransferDelegate];
//        HSLogTrace(@"saving new connection %p", conn);
//        [connections setObject:conn forKey:key];
//    }
//    return conn;
//}
//
//- (void)dropUnusableConnections:(NSTimeInterval)theMaxConnectionLifetime {
//    NSMutableArray *keysToDrop = [NSMutableArray array];
//    for (NSString *key in [connections allKeys]) {
//        id <HTTPConnection> conn = [connections objectForKey:key];
//        if ([conn errorOccurred] || (([NSDate timeIntervalSinceReferenceDate] - [conn createTime]) > theMaxConnectionLifetime)) { // FIXME: Duplicate logic to newConnectionToURL: method
//            [keysToDrop addObject:key];
//        }
//    }
//    if ([keysToDrop count] > 0) {
//        HSLogTrace(@"dropping %@", keysToDrop);
//        [connections removeObjectsForKeys:keysToDrop];
//    }
//}
//@end

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
- (id)retain {
    return self;
}
- (NSUInteger)retainCount {
    return NSUIntegerMax;  //denotes an object that cannot be released
}
- (oneway void)release {
    //do nothing
}
- (id)autorelease {
    return self;
}

- (id)init {
    if (self = [super init]) {
//        lock = [[NSLock alloc] init];
//        [lock setName:@"HTTPConnectionFactory lock"];
//        connectionMapsByThreadId = [[NSMutableDictionary alloc] init];
//        maxConnectionLifetime = DEFAULT_MAX_HTTPCONNECTION_LIFETIME_SECONDS;
//        [NSThread detachNewThreadSelector:@selector(dropUnusableConnections) toTarget:self withObject:nil];
    }
    return self;
}
- (void)dealloc {
//    [lock release];
//    [connectionMapsByThreadId release];
    [super dealloc];
}

- (id <HTTPConnection>)newHTTPConnectionToURL:(NSURL *)theURL
                                       method:(NSString *)theMethod
                         dataTransferDelegate:(id<DataTransferDelegate>)theDataTransferDelegate {
//    id <HTTPConnection> ret = nil;
//    void *pthreadPtr = pthread_self();
//#ifdef __LP64__
//    NSNumber *threadID = [NSNumber numberWithUnsignedLongLong:(uint64_t)pthreadPtr];
//#else
//    NSNumber *threadID = [NSNumber numberWithUnsignedLong:(uint32_t)pthreadPtr];
//#endif
//    [lock lock];
//    ConnectionMap *connMap = [connectionMapsByThreadId objectForKey:threadID];
//    if (connMap == nil) {
//        connMap = [[ConnectionMap alloc] init];
//        [connectionMapsByThreadId setObject:connMap forKey:threadID];
//        [connMap release];
//    }
//    ret = [connMap newConnectionToURL:theURL method:theMethod maxConnectionLifetime:maxConnectionLifetime dataTransferDelegate:theDelegate];
//    [lock unlock];
//    return ret;
    return [[URLConnection alloc] initWithURL:theURL method:theMethod dataTransferDelegate:theDataTransferDelegate];
}

//#pragma mark cleanup thread
//- (void)dropUnusableConnections {
//    [self retain];
//    for (;;) {
//        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
//        [NSThread sleepForTimeInterval:CLEANUP_THREAD_SLEEP_SECONDS];
//        [lock lock];
//        for (ConnectionMap *connMap in [connectionMapsByThreadId allValues]) {
//            @try {
//                [connMap dropUnusableConnections:maxConnectionLifetime];
//            } @catch(NSException *e) {
//                HSLogError(@"unexpected exception in HTTPConnectionFactory cleanup thread: %@", [e description]);
//            }
//        }
//        [lock unlock];
//        [pool drain];
//    }
//}
@end
