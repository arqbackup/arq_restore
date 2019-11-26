/*
 Copyright (c) 2009-2017, Haystack Software LLC https://www.arqbackup.com
 
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
