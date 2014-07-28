//
//  LifecycleConfiguration.m
//  Arq
//
//  Created by Stefan Reitshamer on 2/21/14.
//  Copyright (c) 2014 Stefan Reitshamer. All rights reserved.
//

#import "LifecycleConfiguration.h"

@implementation LifecycleConfiguration
- (id)initWithData:(NSData *)theData error:(NSError **)error {
    if (self = [super init]) {
        elementNames = [[NSMutableArray alloc] init];
        ruleIds = [[NSMutableArray alloc] init];
        NSXMLParser *parser = [[NSXMLParser alloc] initWithData:theData];
        [parser setDelegate:self];
        [parser parse];
        [parser release];
        
        if (errorOccurred) {
            if (error != NULL) {
                *error = [[myError retain] autorelease];
            }
            [self release];
            return nil;
        }
    }
    return self;
}
- (void)dealloc {
    [elementNames release];
    [currentStringBuffer release];
    [ruleIds release];
    [myError release];
    [super dealloc];
}
- (BOOL)containsRuleWithId:(NSString *)theId {
    return [ruleIds containsObject:theId];
}



#pragma mark - NSXMLParserDelegate
- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName
  namespaceURI:(NSString *)namespaceURI
 qualifiedName:(NSString *)qualifiedName
    attributes:(NSDictionary *)attributeDict {
    [elementNames addObject:elementName];
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
    if ([elementNames isEqual:[NSArray arrayWithObjects:@"LifecycleConfiguration", @"Rule", @"ID", nil]]) {
        NSString *ruleId = [[currentStringBuffer copy] autorelease];
        [ruleIds addObject:ruleId];
    }
    [elementNames removeLastObject];
}
- (void)parser:(NSXMLParser *)theParser parseErrorOccurred:(NSError *)parseError {
    HSLogError(@"error parsing amazon response: %@", parseError);
    errorOccurred = YES;
    myError = [parseError retain];
}
- (void)parserDidEndDocument:(NSXMLParser *)parser {
}
@end
