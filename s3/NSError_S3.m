/*
 Copyright (c) 2009, Stefan Reitshamer http://www.haystacksoftware.com
 
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


@implementation NSError (S3)
+ (NSError *)errorFromAmazonXMLData:(NSData *)data statusCode:(int)statusCode {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSString *message = nil;
    NSError *tmpError;
	NSXMLDocument *xmlDoc = [[[NSXMLDocument alloc] initWithData:data options:0 error:&tmpError] autorelease];
	if (xmlDoc != nil) {
        HSLogDebug(@"amazon error XML: %@", [xmlDoc description]);
		NSArray *messages = [xmlDoc nodesForXPath:@"//Error/Message" error:&tmpError];
		if (messages && [messages count] > 0) {
			message = [NSString stringWithFormat:@"Amazon S3 error: %@", [[messages objectAtIndex:0] stringValue]];
		}
    } else {
        HSLogError(@"unable to parse S3 error XML: %@; xml=%@", [tmpError localizedDescription], [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease]);
    }
    if (message == nil) {
        message = [NSString stringWithFormat:@"Amazon S3 error %d", statusCode];
    }
    NSError *error = [NSError errorWithDomain:S3_ERROR_DOMAIN code:statusCode userInfo:[NSDictionary dictionaryWithObjectsAndKeys:message, NSLocalizedDescriptionKey, nil]];
    [error retain];
    [pool drain];
    return [error autorelease];
}
@end
