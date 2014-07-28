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


@class ArrayNode;
@class BooleanNode;
@class DictNode;
@class IntegerNode;
@class RealNode;
@class StringNode;
#import "PListNode.h"

@interface DictNode : NSObject <PListNode, NSCopying> {
	NSMutableDictionary *dict;
	NSMutableArray *orderedKeys;
}
+ (DictNode *)dictNodeWithContentsOfXMLFile:(NSString *)path error:(NSError **)error;
+ (DictNode *)dictNodeWithXMLData:(NSData *)data error:(NSError **)error;
+ (DictNode *)dictNodeWithContentsOfBinaryFile:(NSString *)path error:(NSError **)error;
+ (DictNode *)dictNodeWithBinaryData:(NSData *)data error:(NSError **)error;

- (int)size;
- (BOOL)containsKey:(NSString *)key;
- (NSArray *)keySet;
- (NSArray *)orderedKeySet;
- (NSArray *)values;
- (int)nodeTypeForKey:(NSString *)key;
- (id <PListNode>)nodeForKey:(NSString *)key;
- (ArrayNode *)arrayNodeForKey:(NSString *)key;
- (BooleanNode *)booleanNodeForKey:(NSString *)key;
- (DictNode *)dictNodeForKey:(NSString *)key;
- (IntegerNode *)integerNodeForKey:(NSString *)key;
- (RealNode *)realNodeForKey:(NSString *)key;
- (StringNode *)stringNodeForKey:(NSString *)key;
- (void)putString:(NSString *)value forKey:(NSString *)key;
- (void)putInt:(int)value forKey:(NSString *)key;
- (void)putLongLong:(long long)value forKey:(NSString *)key;
- (void)putBoolean:(BOOL)value forKey:(NSString *)key;
- (void)putDouble:(double)value forKey:(NSString *)key;
- (void)put:(id <PListNode>)value forKey:(NSString *)key;
- (void)removeKey:(NSString *)key;
- (void)removeAllObjects;

- (BOOL)writeXMLToFile:(NSString *)path targetUID:(uid_t)theTargetUID targetGID:(uid_t)theTargetGID error:(NSError **)error;
- (NSData *)XMLData;

- (BOOL)isEqualToDictNode:(DictNode *)dictNode;
@end
