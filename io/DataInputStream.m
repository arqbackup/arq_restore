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

#import "DataInputStream.h"
#import "SetNSError.h"
#import "NSErrorCodes.h"

@implementation DataInputStream
- (id)initWithData:(NSData *)theData {
    if (self = [super init]) {
        data = [theData retain];
    }
    return self;
}
- (id)initWithData:(NSData *)theData offset:(unsigned long long)theOffset length:(unsigned long long)theLength {
    if (self = [super init]) {
        data = [theData subdataWithRange:NSMakeRange((NSUInteger)theOffset, (NSUInteger)theLength)];
    }
    return self;
}
- (void)dealloc {
    [data release];
    [super dealloc];
}

#pragma mark InputStream protocol
- (unsigned char *)read:(NSUInteger *)length error:(NSError **)error {
    if (pos >= [data length]) {
        SETNSERROR(@"StreamsErrorDomain", ERROR_EOF, @"EOF on data");
        return NULL;
    }
    NSUInteger remaining = [data length] - pos;
    *length = remaining;
    unsigned char *ret = (unsigned char *)[data bytes] + pos;
    pos = [data length];
    return ret;
}
- (unsigned char *)readMaximum:(NSUInteger)maximum length:(NSUInteger *)length error:(NSError **)error {
    if (pos >= [data length]) {
        SETNSERROR(@"StreamsErrorDomain", ERROR_EOF, @"EOF on data");
        return NULL;
    }
    NSUInteger len = [data length] - pos;
    if (len > maximum) {
        len = maximum;
    }
    unsigned char *buf = (unsigned char *)[data bytes] + pos;
    pos += len;
    return buf;
}
- (NSData *)slurp:(NSError **)error {
    if (pos == 0) {
        /* This is both a short-circuit and a hack.
         * The short-circuit part is avoiding copying 'data'.
         * The hack part is if [data length] == 0, we return the empty 'data' instead of an EOF error.
         */
        return [[data retain] autorelease];
    }
    if (pos >= [data length]) {
        SETNSERROR(@"StreamsErrorDomain", ERROR_EOF, @"EOF on data");
        return NULL;
    }
    NSData *ret = [data subdataWithRange:NSMakeRange(pos, [data length] - pos)];
    pos = [data length];
    return ret;
}
- (uint64_t)bytesReceived {
    return (uint64_t)pos;
}

#pragma mark BufferedInputStream protocol
- (unsigned char *)readExactly:(NSUInteger)exactLength error:(NSError **)error {
    if (([data length] - pos) < exactLength) {
        SETNSERROR(@"StreamsErrorDomain", ERROR_EOF, @"EOF");
        return NULL;
    }
    unsigned char *buf = (unsigned char *)[data bytes] + pos;
    pos += exactLength;
    return buf;
}
@end
