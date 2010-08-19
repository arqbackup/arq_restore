//
//  XMLPListWriter.m
//  Backup
//
//  Created by Stefan Reitshamer on 4/13/09.
//  Copyright 2009 PhotoMinds LLC. All rights reserved.
//

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
	int size = [node size];
	for (int i = 0; i < size; i++) {
		[self writePListNode:[node objectAtIndex:i] toElement:arrayElem];
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
		NSXMLElement *keyElem = [[NSXMLElement alloc] initWithName:@"key"];
		[keyElem setStringValue:key];
		[dictElem addChild:keyElem];
		[keyElem release];
		[self writePListNode:[node nodeForKey:key] toElement:dictElem];
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
