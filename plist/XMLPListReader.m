//
//  XMLPListReader.m
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
#import "XMLPListReader.h"
#import "SetNSError.h"

@interface XMLPListReader (internal)
- (ArrayNode *)readArray:(NSXMLNode *)elem error:(NSError **)error;
- (DictNode *)readDict:(NSXMLNode *)elem error:(NSError **)error;
- (id <PListNode>)makeNode:(NSXMLNode *)child error:(NSError **)error;
@end


@implementation XMLPListReader
- (id)initWithData:(NSData *)theData {
	if (self = [super init]) {
		data = [theData retain];
	}
	return self;
}
- (void)dealloc {
	[data release];
	[super dealloc];
}
- (DictNode *)read:(NSError **)error {
	NSXMLDocument *doc = [[NSXMLDocument alloc] initWithData:data options:0	error:error];
	if (!doc) {
        return nil;
	}
    DictNode *dn = nil;
    NSXMLElement *rootElem = [doc rootElement];
    if (![[rootElem name] isEqualToString:@"plist"]) {
        SETNSERROR(@"PListErrorDomain", -1, @"expected root element 'plist'");
        [doc release];
        return nil;
    }
    ArrayNode *an = [self readArray:rootElem error:error];
    if (!an) {
        [doc release];
        return nil;
    }
    if ([an size] != 1) {
        SETNSERROR(@"PListErrorDomain", -1, @"empty root array in PList");
        [doc release];
        return nil;
    }
    if ([an arrayElementsType] != PLN_DICT) {
        SETNSERROR(@"PListErrorDomain", -1, @"expected root array in PList");
        [doc release];
        return nil;
    }
    dn = (DictNode *)[an objectAtIndex:0];
    [doc release];
    return dn;
}
@end

@implementation XMLPListReader (internal)
- (ArrayNode *)readArray:(NSXMLNode *)elem error:(NSError **)error {
	NSMutableArray *nodes = [[NSMutableArray alloc] init];
	NSArray *children = [elem children];
	for (NSXMLNode *childNode in children) {
		if ([childNode kind] == NSXMLTextKind) {
			// Skip.
		} else {
            id <PListNode> node = [self makeNode:childNode error:error];
            if (!node) {
                [nodes release];
                return NO;
            }
			[nodes addObject:node];
		}
	}
	ArrayNode *ret = [[[ArrayNode alloc] initWithArray:nodes] autorelease];
	[nodes release];
	return ret;
}
- (DictNode *)readDict:(NSXMLNode *)elem error:(NSError **)error {
	DictNode *dn = [[[DictNode alloc] init] autorelease];
	NSArray *children = [elem children];
	NSString *key = nil;
	for (NSXMLNode *childNode in children) {
		if ([childNode kind] == NSXMLTextKind) {
			// Skip.
		} else {
			NSString *childNodeName = [childNode name];
			if ([childNodeName isEqualToString:@"key"]) {
				key = [childNode stringValue];
			} else {
                id <PListNode> node = [self makeNode:childNode error:error];
                if (!node) {
                    return NO;
                }
				NSAssert(key != nil, @"must have key before adding value");
				[dn put:node forKey:key];
			}
		}
	}
	return dn;
}
- (id <PListNode>)makeNode:(NSXMLNode *)child error:(NSError **)error {
	NSString *childName = [child name];
	id <PListNode> ret = nil;
	if ([childName isEqualToString:@"array"]) {
		ret = [self readArray:child error:error];
	} else if ([childName isEqualToString:@"dict"]) {
		ret = [self readDict:child error:error];
	} else if ([childName isEqualToString:@"true"]) {
		ret = [[[BooleanNode alloc] initWithBoolean:YES] autorelease];
	} else if ([childName isEqualToString:@"false"]) {
		ret = [[[BooleanNode alloc] initWithBoolean:NO] autorelease];
	} else if ([childName isEqualToString:@"integer"]) {
        IntegerNode *node = [[[IntegerNode alloc] initWithString:[child stringValue] error:error] autorelease];
        if (node) {
            ret = node;
        }
	} else if ([childName isEqualToString:@"real"]) {
		RealNode *node = [[[RealNode alloc] initWithString:[child stringValue] error:error] autorelease];
        if (node) {
            ret = node;
        }
	} else if ([childName isEqualToString:@"string"]) {
        NSString *value = (NSString *)CFXMLCreateStringByUnescapingEntities(kCFAllocatorDefault, (CFStringRef)[child stringValue], NULL);
		ret = [[[StringNode alloc] initWithString:value] autorelease];
        [value release];
	} else {
        SETNSERROR(@"PListErrorDomain", -1, @"invalid node type");
	}
	return ret;
}
@end
