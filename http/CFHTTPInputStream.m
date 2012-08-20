//
//  CFHTTPInputStream.m
//  Arq
//
//  Created by Stefan Reitshamer on 3/16/12.
//  Copyright 2012 __MyCompanyName__. All rights reserved.
//

#import "CFHTTPInputStream.h"
#import "HTTPConnectionDelegate.h"
#import "CFHTTPConnection.h"
#import "NetMonitor.h"

@interface CFHTTPConnection (callback)
- (void)sentRequestBytes:(NSInteger)count;
@end

@implementation CFHTTPInputStream
- (id)initWithCFHTTPConnection:(CFHTTPConnection *)theConn data:(NSData *)theData httpConnectionDelegate:(id <HTTPConnectionDelegate>)theHTTPConnectionDelegate {
    if (self = [super init]) {
        conn = theConn; // Don't retain the connection.
        inputStream = [[NSInputStream inputStreamWithData:theData] retain];
        httpConnectionDelegate = theHTTPConnectionDelegate;
        netMonitor = [[NetMonitor alloc] init];
    }
    return self;
}
- (void)dealloc {
    [inputStream release];
    [netMonitor release];
    [super dealloc];
}

- (NSInteger)read:(uint8_t *)buffer maxLength:(NSUInteger)len {
    NSTimeInterval currentTime = [NSDate timeIntervalSinceReferenceDate];        
    if (throttleType == THROTTLE_FIXED && throttleKBPS != 0) {
        // Don't send more than 1/10th of the max bytes/sec:
        NSUInteger maxLen = throttleKBPS * 100;
        if (len > maxLen) {
            len = maxLen;
        }

        if (lastReceivedTime != 0) {
            NSTimeInterval interval = currentTime - lastReceivedTime;
            
            // For some reason Activity Monitor reports "Data sent/sec" at twice what we seem to be sending!
            // So we send half as much -- we divide by 500 instead of 1000 here:
            NSTimeInterval throttledInterval = (double)lastReceivedLength / ((double)throttleKBPS * (double)500.0);
            
            if (throttledInterval > interval) {
                [NSThread sleepForTimeInterval:(throttledInterval - interval)];
            }
        }
    }
    
    if (throttleType == THROTTLE_AUTOMATIC) {
        NSTimeInterval interval = currentTime - lastReceivedTime;
        if (lastReceivedLength > 0) {
            double myBPS = (double)lastReceivedLength / interval;
            double throttle = [netMonitor sample:myBPS];
            if (throttle < 1.0) {
                HSLogDebug(@"throttle = %f", throttle);
            }
            NSTimeInterval throttledInterval = (throttle == 0) ? 0.5 : ((interval / throttle) - interval);
            if (throttledInterval > 0) {
                if (throttledInterval > 0.5) {
                    throttledInterval = 0.5;
                }
                HSLogDebug(@"auto-throttle: sleeping %f seconds", throttledInterval);
                [NSThread sleepForTimeInterval:throttledInterval];
            }
        }
    }
    
    NSInteger ret = [inputStream read:buffer maxLength:len];
    if (ret >= 0) {
        if ([httpConnectionDelegate respondsToSelector:@selector(httpConnection:sentBytes:throttleType:throttleKBPS:pauseRequested:abortRequested:)]) {
            BOOL pauseRequested = NO;
            BOOL abortRequested = NO;
            [httpConnectionDelegate httpConnection:conn sentBytes:ret throttleType:&throttleType throttleKBPS:&throttleKBPS pauseRequested:&pauseRequested abortRequested:&abortRequested];
            if (pauseRequested || abortRequested) {
                return -1;
            }        
        }
        lastReceivedTime = currentTime;
        lastReceivedLength = ret;
        totalReceivedLength += ret;
    }
    [conn sentRequestBytes:ret];
    return ret;
}


// Implement most of the NSInputStream methods:
- (void)open {
    [inputStream open];
}
- (void)close {
    [inputStream close];
}
- (id)delegate {
    return [inputStream delegate];
}
- (void)setDelegate:(id)theDelegate {
    [inputStream setDelegate:theDelegate];
}
- (void)scheduleInRunLoop:(NSRunLoop *)aRunLoop forMode:(NSString *)mode {
    [inputStream scheduleInRunLoop:aRunLoop forMode:mode];
}
- (void)removeFromRunLoop:(NSRunLoop *)aRunLoop forMode:(NSString *)mode {
    [inputStream removeFromRunLoop:aRunLoop forMode:mode];
}
- (id)propertyForKey:(NSString *)key {
    return [inputStream propertyForKey:key];
}
- (BOOL)setProperty:(id)property forKey:(NSString *)key {
    return [inputStream setProperty:property forKey:key];
}
- (NSStreamStatus)streamStatus {
    return [inputStream streamStatus];
}
- (NSError *)streamError {
    return [inputStream streamError];
}


// Forward everything else to the inputStream ivar.
- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector {
    return [inputStream methodSignatureForSelector:aSelector];
}
- (void)forwardInvocation:(NSInvocation *)anInvocation {
    [anInvocation invokeWithTarget:inputStream];
}

@end
