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




#import "DataInputStream.h"



@implementation DataInputStream
- (id)initWithData:(NSData *)theData description:(NSString *)theDescription {
    if (self = [super init]) {
        data = [theData retain];
        description = [theDescription retain];
    }
    return self;
}
- (id)initWithData:(NSData *)theData description:(NSString *)theDescription offset:(unsigned long long)theOffset length:(unsigned long long)theLength {
    if (self = [super init]) {
        data = [theData subdataWithRange:NSMakeRange((NSUInteger)theOffset, (NSUInteger)theLength)];
        description = [theDescription retain];
    }
    return self;
}
- (void)dealloc {
    [data release];
    [description release];
    [super dealloc];
}

#pragma mark InputStream protocol
- (NSInteger)read:(unsigned char *)buf bufferLength:(NSUInteger)bufferLength error:(NSError **)error {
    NSInteger ret = 0;
    NSUInteger remaining = [data length] - pos;
    if (remaining > 0) {
        ret = remaining > bufferLength ? bufferLength : remaining;
        unsigned char *bytes = (unsigned char *)[data bytes];
        memcpy(buf, bytes + pos, ret);
        pos += ret;
    }
    return ret;
}
- (NSData *)slurp:(NSError **)error {
    NSData *ret = nil;
    if (pos == 0) {
        ret = [[data retain] autorelease];
    } else if (pos >= [data length]) {
        ret = [NSData data];
    } else {
        ret = [data subdataWithRange:NSMakeRange(pos, [data length] - pos)];
        pos = [data length];
    }
    return ret;
}


#pragma mark NSObject
- (NSString *)description {
    return [NSString stringWithFormat:@"<DataInputStream: %ld bytes: %@>", (unsigned long)[data length], description];
}
@end
