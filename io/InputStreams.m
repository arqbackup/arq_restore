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

#import "InputStreams.h"
#import "SetNSError.h"
#import "NSErrorCodes.h"
#import "FDInputStream.h"


@implementation InputStreams
+ (NSData *)slurp:(id <InputStream>)is error:(NSError **)error {
    NSMutableData *data = [[[NSMutableData alloc] init] autorelease];
    for (;;) {
        NSError *myError = nil;
        NSUInteger received;
        unsigned char *buf = [is read:&received error:&myError];
        if (buf == NULL) {
            if ([myError code] != ERROR_EOF) {
                data = nil;
                if (error != NULL) {
                    *error = myError;
                }
            }
            break;
        }
        [data appendBytes:buf length:received];
    }
    return data;
}
+ (NSString *)readLineWithCRLF:(FDInputStream *)is maxLength:(NSUInteger)maxLength error:(NSError **)error {
    NSMutableData *data = [[[NSMutableData alloc] init] autorelease];
    for (;;) {
        if ([data length] > maxLength) {
            SETNSERROR(@"InputStreamErrorDomain", -1, @"exceeded maxLength %u", maxLength);
            return nil;
        }
        NSUInteger received = 0;
        unsigned char *buf = [is readMaximum:1 length:&received error:error];
        if (buf == NULL) {
            return nil;
        }
        NSAssert(received == 1, @"expected 1 byte from readMaximum:");
        [data appendBytes:buf length:1];
        char c = buf[0];
        if (c == '\r') {
            buf = [is readMaximum:1 length:&received error:error];
            if (buf == NULL) {
                return nil;
            }
            NSAssert(received == 1, @"expected 1 byte from readMaximum:");
            [data appendBytes:buf length:1];
            c = buf[0];
            if (c == '\n') {
                break;
            }
        }
    }
    NSString *line = [[[NSString alloc] initWithBytes:[data bytes] length:[data length] encoding:NSUTF8StringEncoding] autorelease];
    HSLogTrace(@"got line <%@>", [line substringToIndex:[line length] - 2]);
    return line;
}
+ (NSString *)readLine:(FDInputStream *)is error:(NSError **)error {
    NSMutableData *data = [[[NSMutableData alloc] init] autorelease];
    for (;;) {
        NSUInteger received = 0;
        NSError *myError = nil;
        unsigned char *buf = [is readMaximum:1 length:&received error:&myError];
        if (buf == NULL) {
            if ([myError code] != ERROR_EOF) {
                if (error != NULL) {
                    *error = myError;
                }
                return nil;
            }
            //EOF.
            break;
        }
        NSAssert(received == 1, @"expected 1 byte from readMaximum:");
        if (buf[0] == '\n') {
            break;
        }
        [data appendBytes:buf length:1];
    }
    return [[[NSString alloc] initWithBytes:[data bytes] length:[data length] encoding:NSUTF8StringEncoding] autorelease];
}
@end
