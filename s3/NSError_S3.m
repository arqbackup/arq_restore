/*
 Copyright (c) 2009-2011, Stefan Reitshamer http://www.haystacksoftware.com
 
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

#import "NSError_S3.h"
#import "S3Service.h"
#import "NSXMLNode_extra.h"
#import "NSError_extra.h"


@interface NSError (S3Internal)
+ (NSXMLNode *)errorNodeWithinXMLData:(NSData *)theXMLData;
@end

@implementation NSError (S3)
+ (NSError *)amazonErrorWithHTTPStatusCode:(int)theHTTPStatusCode responseBody:(NSData *)theResponseBody {
    NSXMLNode *errorNode = [NSError errorNodeWithinXMLData:theResponseBody];
    if (errorNode == nil) {
        return [NSError errorWithDomain:[S3Service errorDomain] code:S3SERVICE_ERROR_UNEXPECTED_RESPONSE userInfo:[NSDictionary dictionaryWithObject:@"error parsing S3 response" forKey:NSLocalizedDescriptionKey]];
    }
    NSString *errorCode = [[errorNode childNodeNamed:@"Code"] stringValue];
    NSString *errorMessage = [[errorNode childNodeNamed:@"Message"] stringValue];
    NSString *endpoint = [[errorNode childNodeNamed:@"Endpoint"] stringValue];
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
    [userInfo setObject:[NSNumber numberWithInt:theHTTPStatusCode] forKey:@"HTTPStatusCode"];
    if (errorCode != nil) {
        [userInfo setObject:errorCode forKey:@"AmazonCode"];
    }
    if (errorMessage != nil) {
        [userInfo setObject:errorMessage forKey:@"AmazonMessage"];
    }
    if (endpoint != nil) {
        [userInfo setObject:endpoint forKey:@"AmazonEndpoint"];
    }
    NSString *description = @"Amazon error";
    if (errorCode != nil && errorMessage != nil) {
        description = errorMessage;
        NSMutableString *details = [NSMutableString stringWithFormat:@"Code=%@; Message=%@", errorCode, errorMessage];
        if (endpoint != nil) {
            [details appendFormat:@"; Endpoint=%@", endpoint];
        }
        NSError *underlying = [NSError errorWithDomain:@"AmazonErrorDomain" code:theHTTPStatusCode description:details];
        [userInfo setObject:underlying forKey:NSUnderlyingErrorKey];
    }
    [userInfo setObject:description forKey:NSLocalizedDescriptionKey];
    return [NSError errorWithDomain:[S3Service errorDomain] code:S3SERVICE_ERROR_AMAZON_ERROR userInfo:userInfo];
}
@end

@implementation NSError (S3Internal)
+ (NSXMLNode *)errorNodeWithinXMLData:(NSData *)theXMLData {
    NSError *parseError = nil;
    NSXMLDocument *xmlDoc = [[[NSXMLDocument alloc] initWithData:theXMLData options:0 error:&parseError] autorelease];
    if (xmlDoc == nil) {
        HSLogError(@"error parsing S3 response: %@", [parseError localizedDescription]);
        return nil;
    }
    NSArray *errorNodes = [[xmlDoc rootElement] nodesForXPath:@"//Error" error:&parseError];
    
    if (errorNodes == nil) {
        HSLogError(@"error finding Error node in Amazon error XML: %@", [parseError localizedDescription]);
        return nil;
    }
    
    if ([errorNodes count] == 0) {
        HSLogWarn(@"missing Error node in S3 XML response");
        return nil;
    }
    if ([errorNodes count] > 1) {
        HSLogWarn(@"ignoring additional Error nodes in S3 XML response");
    }
    return [errorNodes objectAtIndex:0];
}
@end
