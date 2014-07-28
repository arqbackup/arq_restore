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


#import "NSError_Glacier.h"
#import "NSXMLNode_extra.h"
#import "NSError_extra.h"
#import "GlacierService.h"
#import "NSString+SBJSON.h"


@implementation NSError (Glacier)
+ (NSError *)glacierErrorWithDomain:(NSString *)theDomain httpStatusCode:(int)theHTTPStatusCode responseBody:(NSData *)theResponseBody {
    NSString *msg = [[[NSString alloc] initWithData:theResponseBody encoding:NSUTF8StringEncoding] autorelease];
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithObject:[NSString stringWithFormat:@"Glacier error %d", theHTTPStatusCode] forKey:NSLocalizedDescriptionKey];
    if (msg != nil) {
        NSDictionary *json = [msg JSONValue:NULL];
        if (json != nil && [json isKindOfClass:[NSDictionary class]]) {
            if ([json objectForKey:@"message"] != nil) {
                [userInfo setObject:[json objectForKey:@"message"] forKey:NSLocalizedDescriptionKey];
                [userInfo setObject:[json objectForKey:@"message"] forKey:@"AmazonMessage"];
            }
            if ([json objectForKey:@"code"] != nil) {
                [userInfo setObject:[json objectForKey:@"code"] forKey:@"AmazonCode"];
            }
        }
    }
    if ([[userInfo objectForKey:@"AmazonCode"] isEqualToString:@"SubscriptionRequiredException"]) {
        [userInfo setObject:@"Your AWS account is not signed up for all services. Please visit http://aws.amazon.com and sign up for S3, Glacier, SNS and SQS." forKey:NSLocalizedDescriptionKey];
    }
    [userInfo setObject:[NSNumber numberWithInt:theHTTPStatusCode] forKey:@"HTTPStatusCode"];
    return [NSError errorWithDomain:theDomain code:GLACIER_ERROR_AMAZON_ERROR userInfo:userInfo];
}
@end
