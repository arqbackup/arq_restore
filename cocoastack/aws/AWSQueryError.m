/*
 Copyright (c) 2009-2014, Stefan Reitshamer http://www.haystacksoftware.com
 
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
