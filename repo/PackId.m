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


#import "PackId.h"

@implementation PackId
- (id)initWithPackSetName:(NSString *)thePackSetName packSHA1:(NSString *)thePackSHA1 {
    if (self = [super init]) {
        packSetName = [thePackSetName retain];
        packSHA1 = [thePackSHA1 retain];
    }
    return self;
}
- (void)dealloc {
    [packSetName release];
    [packSHA1 release];
    [super dealloc];
}

- (NSString *)packSetName {
    return packSetName;
}
- (NSString *)packSHA1 {
    return packSHA1;
}


#pragma mark NSObject
- (NSString *)description {
    return [NSString stringWithFormat:@"<PackId: packset=%@,sha1=%@>", packSetName, packSHA1];
}
- (NSUInteger)hash {
    return [packSetName hash] + [packSHA1 hash];
}
- (BOOL)isEqual:(id)anObject {
    if (![anObject isKindOfClass:[PackId class]]) {
        return NO;
    }
    PackId *other = (PackId *)anObject;
    return [packSetName isEqualToString:[other packSetName]] && [packSHA1 isEqualToString:[other packSHA1]];
}
@end
