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


#import "PackIndexEntry.h"
#import "PackId.h"


@implementation PackIndexEntry
- (id)initWithPackId:(PackId *)thePackId offset:(unsigned long long)theOffset dataLength:(unsigned long long)theDataLength objectSHA1:(NSString *)theObjectSHA1 {
    if (self = [super init]) {
        packId = [thePackId retain];
        offset = theOffset;
        dataLength = theDataLength;
        objectSHA1 = [theObjectSHA1 copy];
    }
    return self;
}
- (void)dealloc {
    [packId release];
    [objectSHA1 release];
    [super dealloc];
}
- (PackId *)packId {
    return packId;
}
- (unsigned long long)offset {
    return offset;
}
- (unsigned long long)dataLength {
    return dataLength;
}
- (NSString *)objectSHA1 {
    return objectSHA1;
}


#pragma mark NSObject
- (NSString *)description {
    return [NSString stringWithFormat:@"<PackIndexEntry: packId=%@ offset=%qu dataLength=%qu objectSHA1=%@>", packId, offset, dataLength, objectSHA1];
}


#pragma mark NSCopying
- (id)copyWithZone:(NSZone *)zone {
    return [[PackIndexEntry alloc] initWithPackId:packId
                                           offset:offset
                                       dataLength:dataLength
                                       objectSHA1:objectSHA1];
}
@end
