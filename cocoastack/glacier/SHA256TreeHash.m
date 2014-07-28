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


#import "SHA256TreeHash.h"
#import "SHA256Hash.h"
#import "NSString_extra.h"


#define ONE_MB (1024 * 1024)

@implementation SHA256TreeHash
+ (NSData *)treeHashOfData:(NSData *)data {
    if ([data length] == 0) {
        return [SHA256Hash hashData:data];
    }
    
    NSMutableArray *hashes = [NSMutableArray array];
    
    const unsigned char *bytes = (const unsigned char *)[data bytes];
    NSUInteger length = [data length];
    NSUInteger index = 0;
    while (index < length) {
        NSUInteger toRead = (index + ONE_MB) > length ? (length - index) : ONE_MB;
        NSData *hash = [SHA256Hash hashBytes:(bytes + index) length:toRead];
        [hashes addObject:hash];
        index += toRead;
    }
    
    while ([hashes count] > 1) {
        NSMutableArray *condensed = [NSMutableArray array];
        for (NSUInteger index = 0; index < [hashes count] / 2; index++) {
            NSMutableData *combined = [NSMutableData dataWithData:[hashes objectAtIndex:(index * 2)]];
            [combined appendData:[hashes objectAtIndex:(index * 2 + 1)]];
            [condensed addObject:[SHA256Hash hashData:combined]];
        }
        if ([hashes count] % 2 == 1) {
            [condensed addObject:[hashes objectAtIndex:([hashes count] - 1)]];
        }
        [hashes setArray:condensed];
    }
    return [hashes objectAtIndex:0];
}
@end
