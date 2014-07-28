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

#import "ArrayNode.h"
#import "BooleanNode.h"
#import "DictNode.h"
#import "IntegerNode.h"
#import "RealNode.h"
#import "StringNode.h"
#import "PListNode.h"
#import "PListNodeType.h"
#import "XMLPListWriter.h"

#define TAB @"\t"

@interface XMLPListWriter (internal)
- (void)writeArray:(ArrayNode *)node toElement:(NSXMLElement *)elem;
- (void)writeBoolean:(BooleanNode *)node toElement:(NSXMLElement *)elem;
- (void)writeDict:(DictNode *)node toElement:(NSXMLElement *)elem;
- (void)writeInteger:(IntegerNode *)node toElement:(NSXMLElement *)elem;
- (void)writeReal:(RealNode *)node toElement:(NSXMLElement *)elem;
- (void)writeString:(StringNode *)node toElement:(NSXMLElement *)elem;
- (void)writePListNode:(id <PListNode>)node toElement:(NSXMLElement *)elem;
@end

@implementation XMLPListWriter
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
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSXMLElement *rootElem = [[NSXMLElement alloc] initWithName:@"plist"];
	NSMutableDictionary *attributes = [[NSMutableDictionary alloc] init];
	[attributes setObject:@"1.0" forKey:@"version"];
	[rootElem setAttributesAsDictionary:attributes];
    [attributes release];
	[self writeDict:plist toElement:rootElem];
	NSXMLDocument *doc = [[NSXMLDocument alloc] initWithRootElement:rootElem];
    [rootElem release];
    NSString *xmlString = [doc XMLStringWithOptions:NSXMLNodePrettyPrint];
    [doc release];
    [data appendData:[xmlString dataUsingEncoding:NSUTF8StringEncoding]];
    [pool drain];
}

@end

@implementation XMLPListWriter (internal)
- (void)writeArray:(ArrayNode *)node toElement:(NSXMLElement *)elem {
	NSXMLElement *arrayElem = [[NSXMLElement alloc] initWithName:@"array"];
	NSUInteger size = [node size];
	for (NSUInteger i = 0; i < size; i++) {
		[self writePListNode:[node objectAtIndex:(int)i] toElement:arrayElem];
	}
	[elem addChild:arrayElem];
	[arrayElem release];
}
- (void)writeBoolean:(BooleanNode *)node toElement:(NSXMLElement *)elem {
	NSXMLElement *childElem;
	if ([node booleanValue]) {
		childElem = [[NSXMLElement alloc] initWithName:@"true"];
	} else {
		childElem = [[NSXMLElement alloc] initWithName:@"false"];
	}
	[elem addChild:childElem];
	[childElem release];
}
- (void)writeDict:(DictNode *)node toElement:(NSXMLElement *)elem {
	NSXMLElement *dictElem = [[NSXMLElement alloc] initWithName:@"dict"];
	NSArray *orderedKeys = [node orderedKeySet];
	for (NSString *key in orderedKeys) {
        id <PListNode> childNode = [node nodeForKey:key];
        if ([childNode type] == PLN_STRING && [(StringNode*)childNode stringValue ] == nil) {
            HSLogTrace(@"skipping nil string dict entry '%@'", key);
        } else {
            NSXMLElement *keyElem = [[NSXMLElement alloc] initWithName:@"key"];
            [keyElem setStringValue:key];
            [dictElem addChild:keyElem];
            [keyElem release];
            [self writePListNode:[node nodeForKey:key] toElement:dictElem];
        }
	}
	[elem addChild:dictElem];
	[dictElem release];
}
- (void)writeInteger:(IntegerNode *)node toElement:(NSXMLElement *)elem {
	NSXMLElement *integerElem = [[NSXMLElement alloc] initWithName:@"integer"];
	[integerElem setStringValue:[NSString stringWithFormat:@"%qi", [node longlongValue]]];
	[elem addChild:integerElem];
	[integerElem release];
}
- (void)writeReal:(RealNode *)node toElement:(NSXMLElement *)elem {
	NSXMLElement *realElem = [[NSXMLElement alloc] initWithName:@"real"];
	[realElem setStringValue:[NSString stringWithFormat:@"%f", [node doubleValue]]];
	[elem addChild:realElem];
	[realElem release];
}
- (void)writeString:(StringNode *)node toElement:(NSXMLElement *)elem {
    if ([node stringValue] == nil) {
        HSLogWarn(@"not writing nil string value to XML plist");
        return;
    }
	NSXMLElement *stringElem = [[NSXMLElement alloc] initWithName:@"string"];
	NSString *value = (NSString *)CFXMLCreateStringByEscapingEntities(kCFAllocatorDefault, (CFStringRef)[node stringValue], NULL);
	[stringElem setStringValue:value];
	[value release];
	[elem addChild:stringElem];
	[stringElem release];
}
- (void)writePListNode:(id <PListNode>)node toElement:(NSXMLElement *)elem {
	int type = [node type];
	switch (type) {
		case PLN_ARRAY:
			[self writeArray:(ArrayNode *)node toElement:elem];
			break;
		case PLN_BOOLEAN:
			[self writeBoolean:(BooleanNode *)node toElement:elem];
			break;
		case PLN_DICT:
			[self writeDict:(DictNode *)node toElement:elem];
			break;
		case PLN_INTEGER:
			[self writeInteger:(IntegerNode *)node toElement:elem];
			break;
		case PLN_REAL:
			[self writeReal:(RealNode *)node toElement:elem];
			break;
		case PLN_STRING:
			[self writeString:(StringNode *)node toElement:elem];
			break;
		default:
            @throw [NSException exceptionWithName:@"InvalidPListNodeTypeException" reason:[NSString stringWithFormat:@"invalid type %d", type] userInfo:nil]; // Programming error.
	}
}
@end
