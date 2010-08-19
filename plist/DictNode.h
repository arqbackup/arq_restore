//
//  DictNode.h
//  Backup
//
//  Created by Stefan Reitshamer on 4/13/09.
//  Copyright 2009 PhotoMinds LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>
@class ArrayNode;
@class BooleanNode;
@class DictNode;
@class IntegerNode;
@class RealNode;
@class StringNode;
#import "PListNode.h"

@interface DictNode : NSObject <PListNode> {
	NSMutableDictionary *dict;
	NSMutableArray *orderedKeys;
}
+ (DictNode *)dictNodeWithContentsOfXMLFile:(NSString *)path error:(NSError **)error;
+ (DictNode *)dictNodeWithXMLData:(NSData *)data error:(NSError **)error;

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

- (BOOL)writeXMLToFile:(NSString *)path error:(NSError **)error;
- (NSData *)XMLData;
@end
