//
//  DictNode.m
//  Backup
//
//  Created by Stefan Reitshamer on 4/13/09.
//  Copyright 2009 PhotoMinds LLC. All rights reserved.
//

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
