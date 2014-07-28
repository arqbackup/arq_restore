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


#import "HTTPInputStream.h"
#import "HTTPConnection.h"
#import "NetMonitor.h"
#import "HTTPThrottle.h"


@implementation HTTPInputStream
- (id)initWithHTTPConnection:(id <HTTPConnection>)theConn data:(NSData *)theData {
    if (self = [super init]) {
        conn = theConn; // Don't retain the connection.
        inputStream = [[NSInputStream inputStreamWithData:theData] retain];
        httpThrottleLock = [[NSLock alloc] init];
        [httpThrottleLock setName:@"HTTPThrottle lock"];
        netMonitor = [[NetMonitor alloc] init];
        throttleType = HTTP_THROTTLE_TYPE_NONE;
    }
    return self;
}
- (void)dealloc {
    [inputStream release];
    [httpThrottleLock release];
    [netMonitor release];
    [super dealloc];
}

- (void)setHTTPThrottle:(HTTPThrottle *)theHTTPThrottle {
    [httpThrottleLock lock];
    throttleType = [theHTTPThrottle throttleType];
    throttleKBPS = [theHTTPThrottle throttleKBPS];
    [httpThrottleLock unlock];
}

- (NSInteger)read:(uint8_t *)buffer maxLength:(NSUInteger)len {
    [httpThrottleLock lock];
    HTTPThrottleType theThrottleType = throttleType;
    NSUInteger theThrottleKBPS = throttleKBPS;
    [httpThrottleLock unlock];
    
    NSTimeInterval currentTime = [NSDate timeIntervalSinceReferenceDate];        
    if (theThrottleType == HTTP_THROTTLE_TYPE_FIXED && theThrottleKBPS != 0) {
        // Don't send more than 1/10th of the max bytes/sec:
        NSUInteger maxLen = theThrottleKBPS * 100;
        if (len > maxLen) {
            len = maxLen;
        }

        if (lastReceivedTime != 0) {
            NSTimeInterval interval = currentTime - lastReceivedTime;
            
            // For some reason Activity Monitor reports "Data sent/sec" at twice what we seem to be sending!
            // So we send half as much -- we divide by 500 instead of 1000 here:
            NSTimeInterval throttledInterval = (double)lastReceivedLength / ((double)theThrottleKBPS * (double)500.0);
            
            if (throttledInterval > interval) {
                [NSThread sleepForTimeInterval:(throttledInterval - interval)];
            }
        }
    }
    
    if (theThrottleType == HTTP_THROTTLE_TYPE_AUTOMATIC) {
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
        lastReceivedTime = currentTime;
        lastReceivedLength = ret;
        totalReceivedLength += ret;
    }
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
