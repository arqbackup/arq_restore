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

#import "PListNode.h"
#import "PListNodeType.h"
#import "ArrayNode.h"
#import "BooleanNode.h"
#import "IntegerNode.h"
#import "RealNode.h"
#import "StringNode.h"
#import "DictNode.h"
#import "XMLPListReader.h"
#import "XMLPListWriter.h"

@implementation DictNode
+ (DictNode *)dictNodeWithContentsOfXMLFile:(NSString *)path error:(NSError **)error {
	NSData *data = [[NSData alloc] initWithContentsOfFile:path options:0 error:error];
    if (!data) {
        return nil;
    }
    DictNode *dn = [DictNode dictNodeWithXMLData:data error:error];
    [data release];
    return dn;
}
+ (DictNode *)dictNodeWithXMLData:(NSData *)data error:(NSError **)error {
    XMLPListReader *reader = [[XMLPListReader alloc] initWithData:data];
	DictNode *dn = [reader read:error];
    [reader release];
	return dn;
}

- (id)init {
	if (self = [super init]) {
		dict = [[NSMutableDictionary alloc] init];
		orderedKeys = [[NSMutableArray alloc] init];
	}
	return self;
}
- (void)dealloc {
	[dict release];
	[orderedKeys release];
	[super dealloc];
}
- (int)size {
	return [dict count];
}
- (BOOL)containsKey:(NSString *)key {
	return [dict objectForKey:key] != nil;
}
- (NSArray *)keySet {
	return [dict allKeys];
}
- (NSArray *)orderedKeySet {
	return orderedKeys;
}
- (NSArray *)values {
	return [dict allValues];
}
- (int)nodeTypeForKey:(NSString *)key {
	id <PListNode> node = [dict objectForKey:key];
	return [node type];
}
- (id <PListNode>)nodeForKey:(NSString *)key {
	return [dict objectForKey:key];
}
- (ArrayNode *)arrayNodeForKey:(NSString *)key {
	return [dict objectForKey:key];
}
- (BooleanNode *)booleanNodeForKey:(NSString *)key {
	return [dict objectForKey:key];
}
- (DictNode *)dictNodeForKey:(NSString *)key {
	return [dict objectForKey:key];
}
- (IntegerNode *)integerNodeForKey:(NSString *)key {
	return [dict objectForKey:key];
}
- (RealNode *)realNodeForKey:(NSString *)key {
	return [dict objectForKey:key];
}
- (StringNode *)stringNodeForKey:(NSString *)key {
	return [dict objectForKey:key];
}
- (void)putString:(NSString *)value forKey:(NSString *)key {
	StringNode *sn = [[StringNode alloc] initWithString:value];
	[self put:sn forKey:key];
	[sn release];
}
- (void)putInt:(int)value forKey:(NSString *)key {
	IntegerNode *in = [[IntegerNode alloc] initWithInt:value];
    [self put:in forKey:key];
	[in release];
}
- (void)putLongLong:(long long)value forKey:(NSString *)key {
	IntegerNode *in = [[IntegerNode alloc] initWithLongLong:value];
    [self put:in forKey:key];
	[in release];
}
- (void)putBoolean:(BOOL)value forKey:(NSString *)key {
	BooleanNode *bn = [[BooleanNode alloc] initWithBoolean:value];
    [self put:bn forKey:key];
	[bn release];
}
- (void)putDouble:(double)value forKey:(NSString *)key {
    RealNode *rn = [[RealNode alloc] initWithDouble:value];
    [self put:rn forKey:key];
    [rn release];
}
- (void)put:(id <PListNode>)value forKey:(NSString *)key {
	[dict setObject:value forKey:key];
	NSUInteger index = [orderedKeys indexOfObject:key];
	if (index != NSNotFound) {
		[orderedKeys removeObjectAtIndex:index];
	}
    [orderedKeys addObject:key];
}
- (void)removeKey:(NSString *)key {
	[dict removeObjectForKey:key];
	NSUInteger index = [orderedKeys indexOfObject:key];
	if (index != NSNotFound) {
		[orderedKeys removeObjectAtIndex:index];
	}
}
- (void)removeAllObjects {
    [dict removeAllObjects];
    [orderedKeys removeAllObjects];
}

- (BOOL)writeXMLToFile:(NSString *)path error:(NSError **)error {
    NSMutableData *data = [[NSMutableData alloc] init];
	XMLPListWriter *writer = [[XMLPListWriter alloc] initWithMutableData:data];
    [writer write:self];
    [writer release];
    BOOL ret = [data writeToFile:path options:NSAtomicWrite error:error];
    [data release];
    return ret;
}
- (NSData *)XMLData {
    NSMutableData *data = [NSMutableData data];
	XMLPListWriter *writer = [[XMLPListWriter alloc] initWithMutableData:data];
    [writer write:self];
    [writer release];
    return data;
}


#pragma mark PListNode protocol

- (int)type {
	return PLN_DICT;
}


#pragma mark NSObject protocol

- (NSString *)description {
    return [NSString stringWithFormat:@"<DictNode 0x%x %@>", self, [dict description]];
}
@end
