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

#import "BinaryPListReader.h"
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
#import "DataInputStream.h"

#import "NSData-InputStream.h"

@interface BinaryPListReader (internal)
- (ArrayNode *)readArray:(NSError **)error;
- (BooleanNode *)readBoolean:(NSError **)error;
- (DictNode *)readDict:(NSError **)error;
- (IntegerNode *)readInteger:(NSError **)error;
- (RealNode *)readReal:(NSError **)error;
- (StringNode *)readString:(NSError **)error;
- (id <PListNode>)readPListNode:(NSError **)error;
@end

@implementation BinaryPListReader
- (id)initWithStream:(BufferedInputStream *)theIS {
	if (self = [super init]) {
		is = [theIS retain];
        if (!is) {
            [self release];
            self = nil;
        }
	}
	return self;
}
- (void)dealloc {
	[is release];
	[super dealloc];
}

- (DictNode *)read:(NSError **)error {
	return [self readDict:error];
}
@end

@implementation BinaryPListReader (internal)
- (ArrayNode *)readArray:(NSError **)error {
	uint32_t size;
    if (![IntegerIO readUInt32:&size from:is error:error]) {
        return nil;
    }
	NSMutableArray *arr = [[NSMutableArray alloc] init];
	for (uint32_t i = 0; i < size; i++) {
        id <PListNode> node = [self readPListNode:error];
        if (!node) {
            [arr release];
            return nil;
        }
		[arr addObject:node];
	}
	ArrayNode *an = [[[ArrayNode alloc] initWithArray:arr] autorelease];
	[arr release];
	return an;
}
- (BooleanNode *)readBoolean:(NSError **)error {
    BOOL value;
    if (![BooleanIO read:&value from:is error:error]) {
        return nil;
    }
	return [[[BooleanNode alloc] initWithBoolean:value] autorelease];
}
- (DictNode *)readDict:(NSError **)error {
	uint32_t size;
    if (![IntegerIO readUInt32:&size from:is error:error]) {
        return nil;
    }
	DictNode *dn = [[[DictNode alloc] init] autorelease];
	for (uint32_t i = 0; i < size; i++) {
		NSString *key;
        if (![StringIO read:&key from:is error:error]) {
            return nil;
        }
        id <PListNode> value = [self readPListNode:error];
        if (!value) {
            return nil;
        }
		[dn put:value forKey:key];
	}
	return dn;
}
- (IntegerNode *)readInteger:(NSError **)error {
    long long value;
    if (![IntegerIO readInt64:&value from:is error:error]) {
        return nil;
    }
	return [[[IntegerNode alloc] initWithLongLong:value] autorelease];
}
- (RealNode *)readReal:(NSError **)error {
    double value;
    if (![DoubleIO read:&value from:is error:error]) {
        return nil;
    }
	return [[[RealNode alloc] initWithDouble:value] autorelease];
}
- (StringNode *)readString:(NSError **)error {
    NSString *value;
    if (![StringIO read:&value from:is error:error]) {
        return nil;
    }
	return [[[StringNode alloc] initWithString:value] autorelease];
}
- (id <PListNode>)readPListNode:(NSError **)error {
	int nodeType;
    if (![IntegerIO readInt32:&nodeType from:is error:error]) {
        return nil;
    }
	id <PListNode> node = nil;
	switch (nodeType) {
		case PLN_ARRAY:
			node = [self readArray:error];
			break;
		case PLN_BOOLEAN:
			node = [self readBoolean:error];
			break;
		case PLN_DICT:
			node = [self readDict:error];
			break;
		case PLN_INTEGER:
			node = [self readInteger:error];
			break;
		case PLN_REAL:
			node = [self readReal:error];
			break;
		case PLN_STRING:
			node = [self readString:error];
			break;
		default:
            SETNSERROR(@"PListErrorDomain", -1, @"invalid node type");
	}
	return node;
}

@end
