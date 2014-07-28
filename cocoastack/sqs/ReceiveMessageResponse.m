//
//  SQSMessage.m
//  Arq
//
//  Created by Stefan Reitshamer on 9/17/12.
//
//

#import "ReceiveMessageResponse.h"
#import "SQSMessage.h"


@implementation ReceiveMessageResponse
- (id)initWithQueueURL:(NSURL *)theQueueURL data:(NSData *)theData {
    if (self = [super init]) {
        queueURL = [theQueueURL retain];
        messages = [[NSMutableArray alloc] init];
        NSXMLParser *parser = [[NSXMLParser alloc] initWithData:theData];
        [parser setDelegate:self];
        [parser parse];
        [parser release];
    }
    return self;
}
- (void)dealloc {
    [queueURL release];
    [messages release];
    [currentStringBuffer release];
    [body release];
    [receiptHandle release];
    [super dealloc];
}
- (NSArray *)messages {
    return messages;
}

#pragma mark - NSXMLParserDelegate
- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName
  namespaceURI:(NSString *)namespaceURI
 qualifiedName:(NSString *)qualifiedName
    attributes:(NSDictionary *)attributeDict {
    [currentStringBuffer release];
    currentStringBuffer = nil;
    if ([elementName isEqualToString:@"Message"]) {
        inMessage = YES;
    }
}
- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string {
    if (currentStringBuffer == nil) {
        currentStringBuffer = [[NSMutableString alloc] init];
    }
    [currentStringBuffer appendString:string];
}
- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName {
    if ([elementName isEqualToString:@"Body"]) {
        [body release];
        body = [currentStringBuffer copy];
    } else if ([elementName isEqualToString:@"ReceiptHandle"]) {
        [receiptHandle release];
        receiptHandle = [currentStringBuffer copy];
    } else if ([elementName isEqualToString:@"Message"]) {
        inMessage = NO;
        SQSMessage *msg = [[[SQSMessage alloc] initWithQueueURL:queueURL body:body receiptHandle:receiptHandle] autorelease];
        [messages addObject:msg];
    }
}
- (void)parser:(NSXMLParser *)theParser parseErrorOccurred:(NSError *)parseError {
    HSLogError(@"error parsing amazon response: %@", parseError);
}
- (void)parserDidEndDocument:(NSXMLParser *)parser {
}
@end
