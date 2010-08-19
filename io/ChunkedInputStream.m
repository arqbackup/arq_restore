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

#import "ChunkedInputStream.h"
#import "SetNSError.h"
#import "InputStreams.h"
#import "NSErrorCodes.h"
#import "FDInputStream.h"

#define MAX_CHUNK_LENGTH_LINE_LENGTH (1024)

@implementation ChunkedInputStream
- (id)initWithUnderlyingStream:(FDInputStream *)is {
    if (self = [super init]) {
        underlyingStream = [is retain];
    }
    return self;
}
- (void)dealloc {
    [underlyingStream release];
    [super dealloc];
}
- (unsigned char *)read:(NSUInteger *)length error:(NSError **)error {
    if (received >= chunkLength) {
        received = 0;
        NSString *line = [InputStreams readLineWithCRLF:underlyingStream maxLength:MAX_CHUNK_LENGTH_LINE_LENGTH error:error];
        if (line == nil) {
            return NULL;
        }
        NSScanner *scanner = [NSScanner scannerWithString:line];
        if (![scanner scanHexInt:&chunkLength]) {
            SETNSERROR(@"StreamErrorDomain", -1, @"invalid chunk length: %@", line);
            return NULL;
        }
        HSLogTrace(@"chunk length = %u", chunkLength);
    }
    unsigned char *buf = NULL;
    if (chunkLength == 0) {
        SETNSERROR(@"StreamsErrorDomain", ERROR_EOF, @"EOF (zero chunk length)");
    } else {
        buf = [underlyingStream readMaximum:(chunkLength - received) length:length error:error];
        if (buf) {
            received += *length;
        }
    }
    if (received >= chunkLength) {
        NSString *line = [InputStreams readLineWithCRLF:underlyingStream maxLength:MAX_CHUNK_LENGTH_LINE_LENGTH error:error];
        if (line == nil) {
            return NULL;
        }
        if (![line isEqualToString:@"\r\n"]) {
            SETNSERROR(@"StreamErrorDomain", -1, @"missing CRLF at end of chunk!");
            return NULL;
        }
    }
    return buf;
}
- (NSData *)slurp:(NSError **)error {
    return [InputStreams slurp:self error:error];
}
@end
