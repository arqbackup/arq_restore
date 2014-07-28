//
//  CreateTopicResponse.m
//
//  Created by Stefan Reitshamer on 9/16/12.
//
//

#import "CreateTopicResponse.h"

@implementation CreateTopicResponse
- (id)initWithData:(NSData *)theData {
    if (self = [super init]) {
        HSLogDebug(@"createtopicresponse: %@", [[[NSString alloc] initWithData:theData encoding:NSUTF8StringEncoding] autorelease]);
        NSXMLParser *parser = [[NSXMLParser alloc] initWithData:theData];
        [parser setDelegate:self];
        [parser parse];
        [parser release];
    }
    return self;
}
- (void)dealloc {
    [topicArn release];
    [currentStringBuffer release];
    [super dealloc];
}

- (NSString *)topicArn {
    return topicArn;
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
            [topicArn release];
            topicArn = [currentStringBuffer copy];
        }
    }
}
- (void)parser:(NSXMLParser *)theParser parseErrorOccurred:(NSError *)parseError {
    HSLogError(@"error parsing amazon response: %@", parseError);
}
- (void)parserDidEndDocument:(NSXMLParser *)parser {
}

@end
