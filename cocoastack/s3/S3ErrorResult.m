//
//  AmazonErrorResult.m
//
//  Created by Stefan Reitshamer on 3/9/12.
//  Copyright (c) 2012 Haystack Software. All rights reserved.
//

#import "S3ErrorResult.h"
#import "S3Service.h"


@implementation S3ErrorResult
- (id)initWithAction:(NSString *)theAction data:(NSData *)theData httpErrorCode:(int)theHTTPStatusCode {
    if (self = [super init]) {
        values = [[NSMutableDictionary alloc] init];
        NSXMLParser *parser = [[NSXMLParser alloc] initWithData:theData];
        [parser setDelegate:self];
        [parser parse];
        [parser release];
        if (errorOccurred) {
            HSLogDebug(@"error parsing amazon result %@", [[[NSString alloc] initWithData:theData encoding:NSUTF8StringEncoding] autorelease]);
            if (theHTTPStatusCode == 500) {
                // DreamObjects can return a 500 with an HTML response body, so we fake it as an Amazon XML error response so that S3Request retries the request:
                NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:500], @"HTTPStatusCode", @"InternalError", @"AmazonCode", nil];
                amazonError = [[NSError errorWithDomain:[S3Service errorDomain] code:S3SERVICE_ERROR_AMAZON_ERROR userInfo:userInfo] retain];
            } else {
                amazonError = [[NSError errorWithDomain:[S3Service errorDomain] code:S3SERVICE_ERROR_AMAZON_ERROR description:[NSString stringWithFormat:@"%@: AWS error", theAction]] retain];
            }
        } else {
            NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
            // Typically we have 'Code', 'Message', and 'Resource' keys in userInfo.
            // We create an error with 'AmazonCode', 'AmazonMessage', 'AmazonResource' and NSLocalizedDescriptionKey.
            [userInfo setObject:[NSNumber numberWithInt:theHTTPStatusCode] forKey:@"HTTPStatusCode"];
            for (NSString *key in [values allKeys]) {
                [userInfo setObject:[values objectForKey:key] forKey:[@"Amazon" stringByAppendingString:key]];
            }
            NSString *msg = nil;
            if ([values objectForKey:@"Message"] == nil) {
                msg = [NSString stringWithFormat:@"S3 error %ld: %@", (unsigned long)theHTTPStatusCode, [userInfo objectForKey:@"AmazonCode"]];
            } else {
                msg = [NSString stringWithFormat:@"%@: %@", theAction, [values objectForKey:@"Message"]];
            }
            [userInfo setObject:msg forKey:NSLocalizedDescriptionKey];
            amazonError = [[NSError errorWithDomain:[S3Service errorDomain] code:S3SERVICE_ERROR_AMAZON_ERROR userInfo:userInfo] retain];
        }
    }
    return self;
}
- (void)dealloc {
    [values release];
    [currentStringBuffer release];
    [amazonError release];
    [super dealloc];
}

- (NSError *)error {
    return amazonError;
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
        [values setObject:[NSString stringWithString:currentStringBuffer] forKey:elementName];
    }
}
- (void)parser:(NSXMLParser *)theParser parseErrorOccurred:(NSError *)parseError {
    errorOccurred = YES;
    HSLogError(@"error parsing amazon error response: %@", parseError);
}
- (void)parserDidEndDocument:(NSXMLParser *)parser {
}

@end
