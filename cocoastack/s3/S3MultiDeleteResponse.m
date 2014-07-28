//
//  S3MultiDeleteResponse.m
//  Arq
//
//  Created by Stefan Reitshamer on 1/13/14.
//  Copyright (c) 2014 Stefan Reitshamer. All rights reserved.
//

#import "S3MultiDeleteResponse.h"

@implementation S3MultiDeleteResponse
- (id)initWithData:(NSData *)theData {
    if (self = [super init]) {
        errorCodesByPath = [[NSMutableDictionary alloc] init];
        
        elementNames = [[NSMutableArray alloc] init];
        NSXMLParser *parser = [[NSXMLParser alloc] initWithData:theData];
        [parser setDelegate:self];
        [parser parse];
        [parser release];
    }
    return self;
}
- (void)dealloc {
    [elementNames release];
    [currentStringBuffer release];
    [errorKey release];
    [errorCode release];
    [errorMessage release];
    [errorCodesByPath release];
    [super dealloc];
}
- (NSDictionary *)errorCodesByPath {
    return errorCodesByPath;
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
    if ([elementNames isEqual:[NSArray arrayWithObjects:@"DeleteResult", @"Error", @"Key", nil]]) {
        [errorKey release];
        errorKey = [currentStringBuffer copy];
    }
    if ([elementNames isEqual:[NSArray arrayWithObjects:@"DeleteResult", @"Error", @"Code", nil]]) {
        [errorCode release];
        errorCode = [currentStringBuffer copy];
    }
    if ([elementNames isEqual:[NSArray arrayWithObjects:@"DeleteResult", @"Error", @"Message", nil]]) {
        [errorMessage release];
        errorMessage = [currentStringBuffer copy];
    }
    if ([elementNames isEqual:[NSArray arrayWithObjects:@"DeleteResult", @"Error", nil]]) {
        HSLogError(@"%@: %@ (%@)", errorKey, errorCode, errorMessage);
        [errorCodesByPath setObject:errorCode forKey:errorKey];
    }
    [elementNames removeLastObject];
}
- (void)parser:(NSXMLParser *)theParser parseErrorOccurred:(NSError *)parseError {
    HSLogError(@"error parsing amazon response: %@", parseError);
}
- (void)parserDidEndDocument:(NSXMLParser *)parser {
}

@end
