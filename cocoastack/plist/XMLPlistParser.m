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

#import "XMLPlistParser.h"


@implementation XMLPlistParser
- (id)initWithContentsOfPath:(NSString *)thePath {
    if (self = [super init]) {
        path = [thePath copy];
        keyNames = [[NSMutableArray alloc] init];
        containerNames = [[NSMutableArray alloc] init];
    }
    return self;
}
- (void)dealloc {
    [currentStringValue release];
    [parser release];
    [path release];
    [keyNames release];
    [containerNames release];
    [super dealloc];
}
- (void)setDelegate:(id <XMLPlistParserDelegate>)theDelegate {
    [delegate release];
    delegate = [theDelegate retain];
}
- (void)parse {
    [parser release];
    parser = [[NSXMLParser alloc] initWithContentsOfURL:[NSURL fileURLWithPath:path]];
    [parser setDelegate:self];
    [parser parse];
}

#pragma mark NSXMLParserDelegate
- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI 
 qualifiedName:(NSString *)qualifiedName attributes:(NSDictionary *)attributeDict {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    if ([elementName isEqualToString:@"dict"]) {
        if ([keyNames count] > 0) {
            if ([[containerNames lastObject] isEqualToString:@"array"]) {
                [delegate parser:self didStartDictInArray:[keyNames lastObject]];
            } else if ([[containerNames lastObject] isEqualToString:@"dict"]) {
                [delegate parser:self didStartDict:[keyNames lastObject]];
            }
        }
        [containerNames addObject:elementName];
    } else if ([elementName isEqualToString:@"array"]) {
        if ([[containerNames lastObject] isEqualToString:@"array"]) {
            [delegate parser:self didStartArrayInArray:[keyNames lastObject]];
        } else if ([[containerNames lastObject] isEqualToString:@"dict"]) {
            [delegate parser:self didStartArray:[keyNames lastObject]];
        }
        [containerNames addObject:elementName];
    } else {
        [currentStringValue release];
        currentStringValue = nil;
    }
    [pool drain];
}
- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string {
    if (currentStringValue == nil) {
        currentStringValue = [[NSMutableString alloc] init];
    }
    [currentStringValue appendString:string];
}
- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    if ([elementName isEqualToString:@"key"]) {
        [keyNames addObject:currentStringValue];
        [currentStringValue release];
        currentStringValue = nil;
    } else if ([elementName isEqualToString:@"string"]) {
        if ([[containerNames lastObject] isEqualToString:@"array"]) {
            [delegate parser:self foundString:currentStringValue inArray:[keyNames lastObject]];
        } else if ([[containerNames lastObject] isEqualToString:@"dict"]) {
            [delegate parser:self foundString:currentStringValue key:[keyNames lastObject]];
            [keyNames removeLastObject];
        }
        [currentStringValue release];
        currentStringValue = nil;
    } else if ([elementName isEqualToString:@"integer"]) {
        if ([[containerNames lastObject] isEqualToString:@"array"]) {
            [delegate parser:self foundInteger:[currentStringValue intValue] inArray:[keyNames lastObject]];
        } else if ([[containerNames lastObject] isEqualToString:@"dict"]) {
            [delegate parser:self foundInteger:[currentStringValue intValue] key:[keyNames lastObject]];
            [keyNames removeLastObject];
        }
        [currentStringValue release];
        currentStringValue = nil;
    } else if ([elementName isEqualToString:@"real"]) {
        double value = 0;
		NSScanner *scanner = [NSScanner scannerWithString:currentStringValue];
		if (![scanner scanDouble:&value]) {
            HSLogError(@"error scanning double from '%@'", currentStringValue);
        }
        if ([[containerNames lastObject] isEqualToString:@"array"]) {
            [delegate parser:self foundReal:value inArray:[keyNames lastObject]];
        } else if ([[containerNames lastObject] isEqualToString:@"dict"]) {
            [delegate parser:self foundReal:value key:[keyNames lastObject]];
            [keyNames removeLastObject];
        }
        [currentStringValue release];
        currentStringValue = nil;
    } else if ([elementName isEqualToString:@"true"]) {
        if ([[containerNames lastObject] isEqualToString:@"array"]) {
            [delegate parser:self foundBoolean:YES inArray:[keyNames lastObject]];
        } else if ([[containerNames lastObject] isEqualToString:@"dict"]) {
            [delegate parser:self foundBoolean:YES key:[keyNames lastObject]];
            [keyNames removeLastObject];
        }
        [currentStringValue release];
        currentStringValue = nil;
    } else if ([elementName isEqualToString:@"false"]) {
        if ([[containerNames lastObject] isEqualToString:@"array"]) {
            [delegate parser:self foundBoolean:NO inArray:[keyNames lastObject]];
        } else if ([[containerNames lastObject] isEqualToString:@"dict"]) {
            [delegate parser:self foundBoolean:NO key:[keyNames lastObject]];
            [keyNames removeLastObject];
        }
        [currentStringValue release];
        currentStringValue = nil;
    } else if ([elementName isEqualToString:@"dict"]) {
        NSAssert([[containerNames lastObject] isEqualToString:elementName], @"must be last object in containerNames");
        [containerNames removeLastObject];
        if ([keyNames count] > 0) {
            if ([[containerNames lastObject] isEqualToString:@"array"]) {
                [delegate parser:self didEndDictInArray:[keyNames lastObject]];
            } else if ([[containerNames lastObject] isEqualToString:@"dict"]) {
                [delegate parser:self didEndDict:[keyNames lastObject]];
                [keyNames removeLastObject];
            }
        }
    } else if ([elementName isEqualToString:@"array"]) {
        NSAssert([[containerNames lastObject] isEqualToString:elementName], @"must be last object in containerNames");
        [containerNames removeLastObject];
        if ([[containerNames lastObject] isEqualToString:@"array"]) {
            [delegate parser:self didEndArrayInArray:[keyNames lastObject]];
        } else if ([[containerNames lastObject] isEqualToString:@"dict"]) {
            [delegate parser:self didEndArray:[keyNames lastObject]];
            [keyNames removeLastObject];
        }
    }
    [pool drain];
}
- (void)parser:(NSXMLParser *)theParser parseErrorOccurred:(NSError *)parseError {
    [delegate parser:self parseErrorOccurred:parseError lineNumber:[theParser lineNumber] columnNumber:[theParser columnNumber]];
}
- (void)parserDidEndDocument:(NSXMLParser *)parser {
    [delegate parserDidEndPlist:self];
}
@end
//- (void)parserDidStartArray:(XMLPlistParser *)parser;
//- (void)parserDidEndArray:(XMLPlistParser *)parser;
//- (void)parserDidStartDict:(XMLPlistParser *)parser;
//- (void)parserDidEndDict:(XMLPlistParser *)parser;
//- (void)parser:(XMLPlistParser *)parser foundDictKey:(NSString *)name;
//- (void)parser:(XMLPlistParser *)parser foundString:(NSString *)value;
//- (void)parser:(XMLPlistParser *)parser foundInteger:(long long)value;
//- (void)parser:(XMLPlistParser *)parser foundBoolean:(BOOL)value;
//- (void)parser:(XMLPlistParser *)parser foundReal:(double)value;
//- (void)parser:(XMLPlistParser *)parser parseErrorOccurred:(NSError *)parseError;
//- (void)parserDidEndPlist:(XMLPlistParser *)parser;
