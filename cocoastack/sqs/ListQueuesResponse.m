//
//  ListQueuesResponse.m
//  Arq
//
//  Created by Stefan Reitshamer on 10/12/12.
//  Copyright (c) 2012 Stefan Reitshamer. All rights reserved.
//

#import "ListQueuesResponse.h"

@implementation ListQueuesResponse
- (id)initWithData:(NSData *)theData {
    if (self = [super init]) {
        queueURLs = [[NSMutableArray alloc] init];
        HSLogDebug(@"listqueuesresponse: %@", [[[NSString alloc] initWithData:theData encoding:NSUTF8StringEncoding] autorelease]);
        NSXMLParser *parser = [[NSXMLParser alloc] initWithData:theData];
        [parser setDelegate:self];
        [parser parse];
        [parser release];
    }
    return self;
}
- (void)dealloc {
    [queueURLs release];
    [currentStringBuffer release];
    [super dealloc];
}
- (NSArray *)queueURLs {
    return queueURLs;
}

#pragma mark - NSXMLParserDelegate
- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName
  namespaceURI:(NSString *)namespaceURI
 qualifiedName:(NSString *)qualifiedName
    attributes:(NSDictionary *)attributeDict {
    [currentStringBuffer release];
    currentStringBuffer = nil;
}
- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string {
    if (currentStringBuffer == nil) {
        currentStringBuffer = [[NSMutableString alloc] init];
    }
    [currentStringBuffer appendString:string];
}
- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName {
    if (currentStringBuffer != nil) {
        if ([elementName isEqualToString:@"QueueUrl"]) {
            NSString *currentString = [[currentStringBuffer copy] autorelease];
            NSURL *theURL = [NSURL URLWithString:currentString];
            if (theURL == nil) {
                HSLogError(@"QueueUrl is invalid: %@", currentString);
            } else {
                [queueURLs addObject:theURL];
            }
        }
    }
}
- (void)parser:(NSXMLParser *)theParser parseErrorOccurred:(NSError *)parseError {
    HSLogError(@"error parsing amazon response: %@", parseError);
}
- (void)parserDidEndDocument:(NSXMLParser *)parser {
}

@end
