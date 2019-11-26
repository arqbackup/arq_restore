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



#import "PListNode.h"
#import "PListNodeType.h"
#import "IntegerNode.h"


@implementation IntegerNode
- (id)initWithInt:(int)theValue {
	if (self = [super init]) {
		value = (long long)theValue;
	}
	return self;
}
- (id)initWithString:(NSString *)theValue error:(NSError **)error {
	if (self = [super init]) {
		NSScanner *scanner = [NSScanner scannerWithString:theValue];
		if (![scanner scanLongLong:&value]) {
            SETNSERROR(@"PListErrorDomain", -1, @"string does not contain a long long: %@", theValue);
            [self release];
            self = nil;
		}
	}
	return self;
}
- (id)initWithLongLong:(long long)theValue {
	if (self = [super init]) {
		value = theValue;
	}
	return self;
}
- (int)intValue {
	return (int)value;
}
- (long long)longlongValue {
	return value;
}
- (BOOL)isEqualToIntegerNode:(IntegerNode *)other {
    if (self == other) {
        return YES;
    }
    return value == [other longlongValue];
}

#pragma mark NSCopying protocol
- (id)copyWithZone:(NSZone *)zone {
    return [[IntegerNode alloc] initWithLongLong:value];
}

#pragma mark PListNode protocol

- (int)type {
	return PLN_INTEGER;
}


#pragma mark NSObject protocol
- (BOOL)isEqual:(id)other {
    if (other == self) {
        return YES;
    }
    if (other == nil || ![other isKindOfClass:[self class]]) {
        return NO;
    }
    return [self isEqualToIntegerNode:other];
}
- (NSUInteger)hash {
    NSUInteger prime = 31;
    NSUInteger result = 1;
    result = prime * result + (NSUInteger)value;
    return result;
}
- (NSString *)description {
    return [NSString stringWithFormat:@"<IntegerNode %qi>", value];
}

@end
