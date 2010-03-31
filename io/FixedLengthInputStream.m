/*
 Copyright (c) 2009, Stefan Reitshamer http://www.haystacksoftware.com
 
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

#import "FixedLengthInputStream.h"
#import "InputStreams.h"
#import "SetNSError.h"
#import "NSErrorCodes.h"
#import "FDInputStream.h"

@implementation FixedLengthInputStream
- (id)initWithUnderlyingStream:(FDInputStream *)is length:(unsigned long long)theLength {
    if (self = [super init]) {
        underlyingStream = [is retain];
        fixedLength = theLength;
    }
    return self;
}
- (void)dealloc {
    [underlyingStream release];
    [super dealloc];
}
- (unsigned char *)read:(NSUInteger *)length error:(NSError **)error {
    unsigned long long maximum = fixedLength - totalReceived;
    if (maximum == 0) {
        SETNSERROR(@"StreamsErrorDomain", ERROR_EOF, @"EOF on fixed length input stream");
        return NULL;
    }
    unsigned char *buf = [underlyingStream readMaximum:maximum length:length error:error];
    if (buf == NULL) {
        return NULL;
    }
    totalReceived += (unsigned long long)(*length);
    return buf;
}
- (NSData *)slurp:(NSError **)error {
    return [InputStreams slurp:self error:error];
}
- (void)bytesWereNotUsed {
}
@end
