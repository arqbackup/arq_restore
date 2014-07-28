//
//  GetQueueAttributesResponse.m
//  Arq
//
//  Created by Stefan Reitshamer on 9/17/12.
//
//

#import "GetQueueAttributesResponse.h"

@implementation GetQueueAttributesResponse
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
    [currentStringBuffer release];
    [lastAttributeName release];
    [queueArn release];
    [super dealloc];
}

- (NSString *)queueArn {
    return queueArn;
}


#pragma mark - NSXMLParserDelegate
- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName
  namespaceURI:(NSString *)namespaceURI
 qualifiedName:(NSString *)qualifiedName
    attributes:(NSDictionary *)attributeDict {
    [currentStringBuffer release];
    currentStringBuffer = nil;
    if ([elementName isEqualToString:@"Attribute"]) {
        inAttribute = YES;
    }
}
- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string {
    if (currentStringBuffer == nil) {
        currentStringBuffer = [[NSMutableString alloc] init];
    }
    [currentStringBuffer appendString:string];
}
- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName {
    if (currentStringBuffer != nil) {
        if (inAttribute) {
            if ([elementName isEqualToString:@"Name"]) {
                [lastAttributeName release];
                lastAttributeName = [currentStringBuffer copy];
            } else if ([elementName isEqualToString:@"Value"]) {
                if ([lastAttributeName isEqualToString:@"QueueArn"]) {
                    [queueArn release];
                    queueArn = [currentStringBuffer copy];
                }
            }
        }
    }
    if ([elementName isEqualToString:@"Attribute"]) {
        inAttribute = NO;
    }
}
- (void)parser:(NSXMLParser *)theParser parseErrorOccurred:(NSError *)parseError {
    HSLogError(@"error parsing amazon response: %@", parseError);
}
- (void)parserDidEndDocument:(NSXMLParser *)parser {
}
@end
