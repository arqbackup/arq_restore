//
//  NSError_Glacier.m
//  Arq
//
//  Created by Stefan Reitshamer on 9/7/12.
//
//

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
