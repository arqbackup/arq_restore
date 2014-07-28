//
//  Created by Stefan Reitshamer on 9/16/12.
//
//

#import "AWSQueryError.h"



@implementation AWSQueryError
- (id)initWithDomain:(NSString *)theDomain httpStatusCode:(int)theCode responseBody:(NSData *)theBody {
    if (self = [super init]) {
        values = [[NSMutableDictionary alloc] init];
        NSXMLParser *parser = [[NSXMLParser alloc] initWithData:theBody];
        [parser setDelegate:self];
        [parser parse];
        [parser release];
        if (parseErrorOccurred) {
            nsError = [[NSError errorWithDomain:theDomain code:theCode description:@"SNS error"] retain];
        } else {
            NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
            [userInfo setObject:[NSNumber numberWithInt:theCode] forKey:@"HTTPStatusCode"];
            for (NSString *key in [values allKeys]) {
                [userInfo setObject:[values objectForKey:key] forKey:[@"Amazon" stringByAppendingString:key]];
            }
            NSString *msg = [values objectForKey:@"Message"];
            if (msg == nil) {
                msg = @"unknown AWS error";
            }
            if ([[userInfo objectForKey:@"AmazonCode"] isEqualToString:@"SubscriptionRequiredException"]) {
                msg = @"Your AWS account is not signed up all services. Please visit http://aws.amazon.com and sign up for S3, Glacier, SNS and SQS.";
            }
            [userInfo setObject:msg forKey:NSLocalizedDescriptionKey];
            nsError = [[NSError errorWithDomain:theDomain code:theCode userInfo:userInfo] retain];
        }
    }
    return self;
}
- (void)dealloc {
    [values release];
    [currentStringBuffer release];
    [nsError release];
    [super dealloc];
}

- (NSError *)nsError {
    return nsError;
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
    parseErrorOccurred = YES;
    HSLogError(@"error parsing amazon error response: %@", parseError);
}
- (void)parserDidEndDocument:(NSXMLParser *)parser {
}

@end
