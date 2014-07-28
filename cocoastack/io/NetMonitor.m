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


#import "NetMonitor.h"
#import "Sysctl.h"

#define OVERHEAD_IN_BYTES (300)
#define THROTTLE_UP_SECONDS (8.0)
#define THRESHOLD_RATIO (.3)

@interface NetMonSample : NSObject {
    NSTimeInterval timeInterval;
    unsigned long long rawBytesIn;
}
@property NSTimeInterval timeInterval;
@property unsigned long long rawBytesIn;
@end
@implementation NetMonSample
@synthesize timeInterval, rawBytesIn;
@end

@implementation NetMonitor
- (id)init {
    if (self = [super init]) {
        currentSample = [[NetMonSample alloc] init];
        previousSample = [[NetMonSample alloc] init];
        NSError *error = nil;
        unsigned long long rawinb;
        unsigned long long rawoutb;
        if (![Sysctl networkBytesIn:&rawinb bytesOut:&rawoutb error:&error]) {
            HSLogError(@"failed to get net stats: %@", [error localizedDescription]);
            [self release];
            return nil;
        }
        currentSample.timeInterval = [NSDate timeIntervalSinceReferenceDate];
        currentSample.rawBytesIn = rawinb;
        overThresholdTime = [[NSDate distantPast] timeIntervalSinceReferenceDate];
        memset(bpsSamples, 0, sizeof(bpsSamples));
    }
    return self;
}
- (void)dealloc {
    [currentSample release];
    [previousSample release];
    [super dealloc];
}
- (double)sample:(double)myBPS {
    bpsSamples[(numBPSSamples++ % 4)] = myBPS;
    double throttle = 1.0;
    if (numBPSSamples > 1) {
        unsigned long long rawinb;
        unsigned long long rawoutb;
        NSError *error = nil;
        if (![Sysctl networkBytesIn:&rawinb bytesOut:&rawoutb error:&error]) {
            HSLogError(@"failed to get net stats: %@", [error localizedDescription]);
        } else {
            previousSample.timeInterval = currentSample.timeInterval;
            previousSample.rawBytesIn = currentSample.rawBytesIn;
            NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
            currentSample.timeInterval = now;
            currentSample.rawBytesIn = rawinb;
            
            // I got a crash once because rawinb was smaller than previousSample.rawBytesIn, so now we check:
            if (rawinb >= previousSample.rawBytesIn) {
                if (previousSample.timeInterval != 0) {
                    unsigned long long bytesIn = currentSample.rawBytesIn - previousSample.rawBytesIn;
                    if (bytesIn > OVERHEAD_IN_BYTES) {
                        bytesIn -= OVERHEAD_IN_BYTES;
                    }
                    NSTimeInterval interval = currentSample.timeInterval - previousSample.timeInterval;
                    double inBPS = (double)bytesIn / interval;
                    double ratio = myBPS == 0 ? 0 : (inBPS / myBPS);
                    BOOL overThreshold = myBPS != 0 && ratio > THRESHOLD_RATIO;
                    HSLogTrace(@"sent: %0.2fBPS bytesIn: %qu (%0.2fBPS) ratio: %0.2f threshold: %0.2f interval: %0.2f %@", myBPS, bytesIn, inBPS, ratio, THRESHOLD_RATIO, interval, (overThreshold ? @": over threshold" : @""));
                    if (overThreshold) {
                        overThresholdTime = [NSDate timeIntervalSinceReferenceDate];
                    }
                }
            }
            
            double secsSinceOverage = now - overThresholdTime;
            if (secsSinceOverage < THROTTLE_UP_SECONDS) {
                throttle = secsSinceOverage / THROTTLE_UP_SECONDS;
                if (throttle < 0.0001) {
                    throttle = 0.0001;
                }
                HSLogTrace(@"secsSinceOverage=%f throttle=%0.2f", secsSinceOverage, throttle);
            }
        }
    }
    return throttle;
}
- (double)averageBPS {
    NSUInteger num = numBPSSamples > 4 ? 4 : numBPSSamples;
    double total = 0.0;
    for (NSUInteger i = 0; i < num; i++) {
        total += bpsSamples[i];
    }
    return total / (double)num;
}
@end
