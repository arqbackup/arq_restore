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

#include <sys/stat.h>
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
#import "BinaryPListWriter.h"

#import "FileInputStream.h"
#import "DataInputStream.h"
#import "BinaryPListReader.h"
#import "BufferedInputStream.h"

@interface DictNode (internal)
- (id)initWithDict:(NSMutableDictionary *)theDict orderedKeys:(NSMutableArray *)theOrderedKeys;
- (NSDictionary *)dict;
@end

@implementation DictNode
+ (DictNode *)dictNodeWithContentsOfXMLFile:(NSString *)path error:(NSError **)error {
	NSData *data = [[NSData alloc] initWithContentsOfFile:path options:0 error:error];
    if (!data) {
        return nil;
    }
    NSError *myError = nil;
    DictNode *dn = [DictNode dictNodeWithXMLData:data error:&myError];
    [data release];
    if (dn == nil) {
        SETNSERROR(@"DictNodeErrorDomain", -1, @"error parsing %@: %@", path, [myError localizedDescription]);
    }
    return dn;
}
+ (DictNode *)dictNodeWithXMLData:(NSData *)data error:(NSError **)error {
    XMLPListReader *reader = [[XMLPListReader alloc] initWithData:data];
	DictNode *dn = [reader read:error];
    [reader release];
	return dn;
}
+ (DictNode *)dictNodeWithContentsOfBinaryFile:(NSString *)path error:(NSError **)error {
    struct stat st;
    if (stat([path fileSystemRepresentation], &st) == -1) {
        int errnum = errno;
        HSLogError(@"lstat(%@) error %d: %s", path, errnum, strerror(errnum));
        SETNSERROR(@"UnixErrorDomain", errnum, @"%@: %s", path, strerror(errnum));
        return nil;
    }
    FileInputStream *fis = [[FileInputStream alloc] initWithPath:path offset:0 length:(unsigned long long)st.st_size];
    BufferedInputStream *bis = [[BufferedInputStream alloc] initWithUnderlyingStream:fis];
    BinaryPListReader *reader = [[BinaryPListReader alloc] initWithStream:bis];
    DictNode *ret = [reader read:error];
    [reader release];
    [bis release];
    [fis release];
    return ret;
}
+ (DictNode *)dictNodeWithBinaryData:(NSData *)data error:(NSError **)error {
    DataInputStream *dis = [[DataInputStream alloc] initWithData:data description:@"DictNode"];
    BufferedInputStream *bis = [[BufferedInputStream alloc] initWithUnderlyingStream:dis];
    BinaryPListReader *reader = [[BinaryPListReader alloc] initWithStream:bis];
    [bis release];
    DictNode *ret = [reader read:error];
    [reader release];
    [dis release];
    return ret;
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
	return (int)[dict count];
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

- (BOOL)writeXMLToFile:(NSString *)path targetUID:(uid_t)theTargetUID targetGID:(uid_t)theTargetGID error:(NSError **)error {
    NSMutableData *data = [[NSMutableData alloc] init];
	XMLPListWriter *writer = [[XMLPListWriter alloc] initWithMutableData:data];
    [writer write:self];
    [writer release];
    BOOL ret = [data writeToFile:path options:NSAtomicWrite error:error];
    [data release];
    if (!ret) {
        return NO;
    }
    if (chown([path fileSystemRepresentation], theTargetUID, theTargetGID) == -1) {
        int errnum = errno;
        SETNSERROR(@"UnixErrorDomain", errnum, @"chown(%@, %d, %d): %s", path, theTargetUID, theTargetGID, strerror(errnum));
        return NO;
    }
    return YES;
}
- (NSData *)XMLData {
    NSMutableData *data = [NSMutableData data];
	XMLPListWriter *writer = [[XMLPListWriter alloc] initWithMutableData:data];
    [writer write:self];
    [writer release];
    return data;
}
- (BOOL)isEqualToDictNode:(DictNode *)dictNode {
    if (self == dictNode) {
        return YES;
    }
    if (![orderedKeys isEqualToArray:[dictNode orderedKeySet]]) {
        return NO;
    }
    if (![dict isEqualToDictionary:[dictNode dict]]) {
        return NO;
    }
    return YES;
}

#pragma mark PListNode protocol

- (int)type {
	return PLN_DICT;
}

#pragma mark NSCopying protocol
- (id)copyWithZone:(NSZone *)zone {
    NSMutableDictionary *dictCopy = [[NSMutableDictionary alloc] initWithDictionary:dict copyItems:YES];
    NSMutableArray *orderedKeysCopy = [[NSMutableArray alloc] initWithArray:orderedKeys copyItems:YES];
    DictNode *dictNodeCopy = [[DictNode alloc] initWithDict:dictCopy orderedKeys:orderedKeysCopy];
    [dictCopy release];
    [orderedKeysCopy release];
    return dictNodeCopy;
}

#pragma mark NSObject protocol
- (BOOL)isEqual:(id)other {
    if (other == self) {
        return YES;
    }
    if (other == nil || ![other isKindOfClass:[self class]]) {
        return NO;
    }
    return [self isEqualToDictNode:other];
}
- (NSUInteger)hash {
    NSUInteger prime = 31;
    NSUInteger result = 1;
    result = prime * result + [dict hash];
    result = prime * result + [orderedKeys hash];
    return result;
}
- (NSString *)description {
    return [NSString stringWithFormat:@"<DictNode %@>", [dict description]];
}
@end

@implementation DictNode (internal)
- (id)initWithDict:(NSMutableDictionary *)theDict orderedKeys:(NSMutableArray *)theOrderedKeys {
    if (self = [super init]) {
        dict = [theDict retain];
        orderedKeys = [theOrderedKeys retain];
    }
    return self;
}
- (NSDictionary *)dict {
    return dict;
}
@end
