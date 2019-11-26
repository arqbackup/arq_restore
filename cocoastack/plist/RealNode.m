/*
 Copyright (c) 2009-2017, Haystack Software LLC https://www.arqbackup.com
 
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



#import "PListNodeType.h"
#import "RealNode.h"


@implementation RealNode
- (id)initWithDouble:(double)theValue {
	if (self = [super init]) {
		value = theValue;
	}
	return self;
}
- (id)initWithString:(NSString *)theValue error:(NSError **)error {
	if (self = [super init]) {
		NSScanner *scanner = [NSScanner scannerWithString:theValue];
		if (![scanner scanDouble:&value]) {
            SETNSERROR(@"PListErrorDomain", -1, @"string does not contain a double: %@", theValue);
            [self release];
            self = nil;
		}
	}
	return self;
}
- (double)doubleValue {
	return value;
}
- (BOOL)isEqualToRealNode:(RealNode *)other {
    if (other == self) {
        return YES;
    }
    return value == [other doubleValue];
}

#pragma mark PListNode protocol

- (int)type {
	return PLN_REAL;
}

#pragma mark NSCopying protocol
- (id)copyWithZone:(NSZone *)zone {
    return [[RealNode alloc] initWithDouble:value];
}

#pragma mark NSObject protocol
- (BOOL)isEqual:(id)other {
    if (other == self) {
        return YES;
    }
    if (other == nil || ![other isKindOfClass:[self class]]) {
        return NO;
    }
    return [self isEqualToRealNode:other];
}
- (NSUInteger)hash {
    NSUInteger prime = 31;
    NSUInteger result = 1;
    result = prime * result + (NSUInteger)value;
    return result;
}
- (NSString *)description {
    return [NSString stringWithFormat:@"<RealNode %f>", value];
}
@end
