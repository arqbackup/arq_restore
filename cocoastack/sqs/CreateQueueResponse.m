//
//  CreateQueueResponse.m
//
//  Created by Stefan Reitshamer on 9/16/12.
//
//

#import "CreateQueueResponse.h"

@implementation CreateQueueResponse
- (id)initWithData:(NSData *)theData {
    if (self = [super init]) {
        NSXMLParser *parser = [[NSXMLParser alloc] initWithData:theData];
        [parser setDelegate:self];
        [parser parse];
        [parser release];
    }
    return self;
}
- (void)dealloc {
    [queueURL release];
    [currentStringBuffer release];
    [super dealloc];
}

- (NSURL *)queueURL {
    return queueURL;
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
            [queueURL release];
            queueURL = [[NSURL alloc] initWithString:currentStringBuffer];
        }
    }
}
- (void)parser:(NSXMLParser *)theParser parseErrorOccurred:(NSError *)parseError {
    HSLogError(@"error parsing amazon response: %@", parseError);
}
- (void)parserDidEndDocument:(NSXMLParser *)parser {
}
@end
