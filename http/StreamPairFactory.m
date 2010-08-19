//
//  StreamPairFactory.m
//  CFN
//
//  Created by Stefan Reitshamer on 2/25/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "StreamPairFactory.h"
#import "CFStreamPair.h"

static StreamPairFactory *theFactory = nil;

#define DEFAULT_MAX_STREAM_PAIR_LIFETIME_SECONDS (60)
#define CLEANUP_THREAD_SLEEP_SECONDS (5)

@interface StreamPairMap : NSObject {
    NSMutableDictionary *streamPairs;
}
- (id <StreamPair>)newStreamPairToHost:(NSString *)host useSSL:(BOOL)useSSL maxLifeTimeSeconds:(NSTimeInterval)theMaxLifetime error:(NSError **)error;
- (void)dropUnusableStreamPairs;
@end

@implementation StreamPairMap
- (id)init {
    if (self = [super init]) {
        streamPairs = [[NSMutableDictionary alloc] init];
    }
    return self;
}
- (void)dealloc {
    [streamPairs release];
    [super dealloc];
}
- (id <StreamPair>)newStreamPairToHost:(NSString *)host useSSL:(BOOL)useSSL maxLifeTimeSeconds:(NSTimeInterval)theMaxLifetime error:(NSError **)error {
    NSString *key = [NSString stringWithFormat:@"%@:%@", [host lowercaseString], (useSSL ? @"SSL" : @"noSSL")];
    id <StreamPair> streamPair = [streamPairs objectForKey:key];
    if (streamPair != nil) {
        if (![streamPair isUsable]) {
            [streamPairs removeObjectForKey:key];
            streamPair = nil;
        } else {
            [streamPair retain];
        }
    }
    if (streamPair == nil) {
        streamPair = [[CFStreamPair alloc] initWithHost:host useSSL:useSSL maxLifetime:theMaxLifetime];
        [streamPairs setObject:streamPair forKey:key];
    }
    return streamPair;
}
- (void)dropUnusableStreamPairs {
    NSMutableArray *keysToDrop = [NSMutableArray array];
    for (NSString *key in streamPairs) {
        id <StreamPair> streamPair = [streamPairs objectForKey:key];
        if (![streamPair isUsable]) {
            [keysToDrop addObject:key];
        }
    }
    [streamPairs removeObjectsForKeys:keysToDrop];
}
@end



@implementation StreamPairFactory
+ (StreamPairFactory *)theFactory {
    if (theFactory == nil) {
        theFactory = [[super allocWithZone:NULL] init];
    }
    return theFactory;
}

/* Singleton recipe: */
+ (id)allocWithZone:(NSZone *)zone {
    return [[StreamPairFactory theFactory] retain];
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
- (void)release {
    //do nothing
}
- (id)autorelease {
    return self;
}

- (id)init {
    if (self = [super init]) {
        lock = [[NSLock alloc] init];
        [lock setName:@"SocketFactory lock"];
        threadMap = [[NSMutableDictionary alloc] init];
        maxStreamPairLifetime = DEFAULT_MAX_STREAM_PAIR_LIFETIME_SECONDS;
        [NSThread detachNewThreadSelector:@selector(dropUnusableSockets) toTarget:self withObject:nil];
    }
    return self;
}
- (void)dealloc {
    [lock release];
    [threadMap release];
    [super dealloc];
}
- (void)setMaxStreamPairLifetime:(NSTimeInterval)theMaxLifetime {
    maxStreamPairLifetime = theMaxLifetime;
}
- (id <StreamPair>)newStreamPairToHost:(NSString *)theHost useSSL:(BOOL)isUseSSL error:(NSError **)error {
    void *pthreadPtr = pthread_self();
#ifdef __LP64__
    NSNumber *threadID = [NSNumber numberWithUnsignedLongLong:(uint64_t)pthreadPtr];
#else
    NSNumber *threadID = [NSNumber numberWithUnsignedLong:(uint32_t)pthreadPtr];
#endif
    [lock lock];
    StreamPairMap *map = [threadMap objectForKey:threadID];
    if (map == nil) {
        map = [[StreamPairMap alloc] init];
        [threadMap setObject:map forKey:threadID];
        [map release];
    }
    id <StreamPair> streamPair = [map newStreamPairToHost:theHost useSSL:isUseSSL maxLifeTimeSeconds:maxStreamPairLifetime error:error];
    [lock unlock];
    return streamPair;
}
- (void)clear {
    [lock lock];
    [threadMap removeAllObjects];
    [lock unlock];
}

#pragma mark cleanup thread
- (void)dropUnusableSockets {
    for (;;) {
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        @try {
            [NSThread sleepForTimeInterval:CLEANUP_THREAD_SLEEP_SECONDS];
            [lock lock];
            for (StreamPairMap *map in [threadMap allValues]) {
                [map dropUnusableStreamPairs];
            }
            [lock unlock];
        } @catch(NSException *e) {
            HSLogError(@"unexpected exception in StreamPairFactory cleanup thread: %@", [e description]);
        }
        [pool drain];
    }
}
@end
