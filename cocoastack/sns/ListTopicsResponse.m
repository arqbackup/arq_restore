//
//  ListTopicsResponse.m
//  Arq
//
//  Created by Stefan Reitshamer on 9/29/12.
//
//

#import "ListTopicsResponse.h"

@implementation ListTopicsResponse
- (id)initWithData:(NSData *)theData {
    if (self = [super init]) {
        topicArns = [[NSMutableArray alloc] init];
        HSLogDebug(@"createtopicresponse: %@", [[[NSString alloc] initWithData:theData encoding:NSUTF8StringEncoding] autorelease]);
        NSXMLParser *parser = [[NSXMLParser alloc] initWithData:theData];
        [parser setDelegate:self];
        [parser parse];
        [parser release];
    }
    return self;
}
- (void)dealloc {
    [topicArns release];
    [currentStringBuffer release];
    [super dealloc];
}
- (NSArray *)topicArns {
    return topicArns;
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
        if ([elementName isEqualToString:@"TopicArn"]) {
            [topicArns addObject:[[currentStringBuffer copy] autorelease]];
        }
    }
}
- (void)parser:(NSXMLParser *)theParser parseErrorOccurred:(NSError *)parseError {
    HSLogError(@"error parsing amazon response: %@", parseError);
}
- (void)parserDidEndDocument:(NSXMLParser *)parser {
}

@end
