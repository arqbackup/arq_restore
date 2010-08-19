/*
 Copyright (c) 2009-2010, Stefan Reitshamer http://www.haystacksoftware.com
 
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

#import "MonitoredInputStream.h"
#import "SetNSError.h"

@implementation MonitoredInputStream
- (id)initWithUnderlyingStream:(id <InputStream>)theUnderlyingStream delegate:(id)theDelegate {
    if (self = [super init]) {
        underlyingStream = [theUnderlyingStream retain];
        delegate = [theDelegate retain];
        NSNotification *notif = [NSNotification notificationWithName:@"MonitoredInputStreamCreated" object:nil];
        [[NSNotificationCenter defaultCenter] performSelectorOnMainThread:@selector(postNotification:) withObject:notif waitUntilDone:NO];
    }
    return self;
}
- (void)dealloc {
    [underlyingStream release];
    [delegate release];
    [super dealloc];
}
- (unsigned char *)read:(NSUInteger *)length error:(NSError **)error {
    unsigned char *buf = [underlyingStream read:length error:error];
    if (buf != NULL) {
        if (![delegate monitoredInputStream:self receivedBytes:*length error:error]) {
            return NULL;
        }
        bytesReceived += (unsigned long long)*length;
    }
    return buf;
}
- (NSData *)slurp:(NSError **)error {
    NSData *data = [underlyingStream slurp:error];
    if (data != nil) {
        if (![delegate monitoredInputStream:self receivedBytes:(unsigned long long)[data length] error:error]) {
            data = nil;
        }
        bytesReceived += (unsigned long long)[data length];
    }
    return data;
}
@end
