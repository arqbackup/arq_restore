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

#import "PListNode.h"
#import "ArrayNode.h"
#import "BooleanNode.h"
#import "DictNode.h"
#import "IntegerNode.h"
#import "RealNode.h"
#import "StringNode.h"
#import "IntegerIO.h"
#import "BooleanIO.h"
#import "StringIO.h"
#import "DoubleIO.h"
#import "PListNodeType.h"
#import "BinaryPListWriter.h"

@interface BinaryPListWriter (internal)
- (void)writeArray:(ArrayNode *)node;
- (void)writeBoolean:(BooleanNode *)node;
- (void)writeDict:(DictNode *)node;
- (void)writeInteger:(IntegerNode *)node;
- (void)writeReal:(RealNode *)node;
- (void)writeString:(StringNode *)node;
- (void)writePListNode:(id <PListNode>)node;
@end

@implementation BinaryPListWriter
- (id)initWithMutableData:(NSMutableData *)theData {
	if (self = [super init]) {
        data = [theData retain];
	}
	return self;
}
- (void)dealloc {
	[data release];
	[super dealloc];
}
- (void)write:(DictNode *)plist {
	[self writeDict:plist];
}
@end

@implementation BinaryPListWriter (internal)
- (void)writeArray:(ArrayNode *)node {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSUInteger size = [node size];
    NSAssert(size < 0xffffffff, @"size is greater than uint32_t max!");
	[IntegerIO writeUInt32:(uint32_t)size to:data]; //FIXME: Should have written 64 bits!
	for (int i = 0; i < size; i++) {
		[self writePListNode:[node objectAtIndex:i]];
	}
    [pool drain];
}
- (void)writeBoolean:(BooleanNode *)node {
	[BooleanIO write:[node booleanValue] to:data];
}
- (void)writeDict:(DictNode *)node {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSArray *orderedKeys = [node orderedKeySet];
    NSUInteger count = [orderedKeys count];
    NSAssert(count < 0xffffffff, @"count is greater than uint32_t max!");
	[IntegerIO writeUInt32:(uint32_t)[orderedKeys count] to:data]; //FIXME: Should have written 64 bits!
	for (NSString *key in orderedKeys) {
		[StringIO write:key to:data];
		[self writePListNode:[node nodeForKey:key]];
	}
    [pool drain];
}
- (void)writeInteger:(IntegerNode *)node {
	[IntegerIO writeInt64:[node longlongValue] to:data];
}
- (void)writeReal:(RealNode *)node {
	[DoubleIO write:[node doubleValue] to:data];
}
- (void)writeString:(StringNode *)node {
	[StringIO write:[node stringValue] to:data];
}
- (void)writePListNode:(id <PListNode>)node {
	int type = [node type];
	[IntegerIO writeInt32:type to:data];
	switch (type) {
		case PLN_ARRAY:
			[self writeArray:(ArrayNode *)node];
			break;
		case PLN_BOOLEAN:
			[self writeBoolean:(BooleanNode *)node];
			break;
		case PLN_DICT:
			[self writeDict:(DictNode *)node];
			break;
		case PLN_INTEGER:
			[self writeInteger:(IntegerNode *)node];
			break;
		case PLN_REAL:
			[self writeReal:(RealNode *)node];
			break;
		case PLN_STRING:
			[self writeString:(StringNode *)node];
			break;
		default:
            @throw [NSException exceptionWithName:@"InvalidPListNodeTypeException" reason:[NSString stringWithFormat:@"invalid type %d", type] userInfo:nil]; // Programming error.
	}
}
@end
