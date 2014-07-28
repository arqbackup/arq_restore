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


#import "SNS.h"
#import "AWSRegion.h"
#import "NSString_extra.h"
#import "SignatureV2Provider.h"
#import "AWSQueryRequest.h"
#import "AWSQueryResponse.h"
#import "CreateTopicResponse.h"
#import "SubscribeResponse.h"
#import "ListTopicsResponse.h"


@implementation SNS
+ (NSString *)errorDomain {
    return @"SNSErrorDomain";
}

- (id)initWithAccessKey:(NSString *)theAccessKey secretKey:(NSString *)secret awsRegion:(AWSRegion *)theAWSRegion retryOnTransientError:(BOOL)retry {
    if (self = [super init]) {
        accessKey = [theAccessKey retain];
        sap = [[SignatureV2Provider alloc] initWithSecretKey:secret];
        awsRegion = [theAWSRegion retain];
        retryOnTransientError = retry;
    }
    return self;
}
- (void)dealloc {
    [accessKey release];
    [sap release];
    [awsRegion release];
    [super dealloc];
}

- (NSString *)createTopic:(NSString *)theName error:(NSError **)error {
    NSDateFormatter *formatter = [[[NSDateFormatter alloc] init] autorelease];
    [formatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss'Z'"];
    [formatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
    
    NSMutableString *str = [NSMutableString stringWithFormat:@"%@/?", [awsRegion snsEndpointWithSSL:NO]];
    [str appendFormat:@"AWSAccessKeyId=%@", [accessKey stringByEscapingURLCharacters]];
    [str appendFormat:@"&Action=CreateTopic"];
//    [str appendFormat:@"&Expires=%ld", (NSUInteger)[[[NSDate date] dateByAddingTimeInterval:30.0] timeIntervalSince1970]];
    [str appendFormat:@"&Name=%@", [theName stringByEscapingURLCharacters]];
    [str appendFormat:@"&SignatureMethod=HmacSHA256"];
    [str appendFormat:@"&SignatureVersion=2"];
    [str appendFormat:@"&Timestamp=%@", [[formatter stringFromDate:[NSDate date]] stringByEscapingURLCharacters]];
    NSURL *url = [NSURL URLWithString:str];
    NSAssert(url != nil, @"url may not be nil!");
    NSString *signature = [sap signatureForHTTPMethod:@"GET" url:url];
    [str appendFormat:@"&Signature=%@", [signature stringByEscapingURLCharacters]];

    NSURL *urlWithSignature = [NSURL URLWithString:str];
    AWSQueryRequest *req = [[[AWSQueryRequest alloc] initWithMethod:@"GET" url:urlWithSignature retryOnTransientError:retryOnTransientError] autorelease];
    AWSQueryResponse *response = [req execute:error];
    if (response == nil) {
        return nil;
    }
    CreateTopicResponse *ctr = [[[CreateTopicResponse alloc] initWithData:[response body]] autorelease];
    NSString *ret = [ctr topicArn];
    if (ret == nil) {
        SETNSERROR([SNS errorDomain], -1, @"TopicArn not found in CreateTopic response");
    }
    return ret;
}
- (NSString *)subscribeQueueArn:(NSString *)theQueueArn toTopicArn:(NSString *)theTopicArn error:(NSError **)error {
    NSDateFormatter *formatter = [[[NSDateFormatter alloc] init] autorelease];
    [formatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss'Z'"];
    [formatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
    
    NSMutableString *str = [NSMutableString stringWithFormat:@"%@/?", [awsRegion snsEndpointWithSSL:NO]];
    [str appendFormat:@"AWSAccessKeyId=%@", [accessKey stringByEscapingURLCharacters]];
    [str appendFormat:@"&Action=Subscribe"];
    [str appendFormat:@"&Endpoint=%@", [theQueueArn stringByEscapingURLCharacters]];
    [str appendFormat:@"&Protocol=sqs"];
    [str appendFormat:@"&SignatureMethod=HmacSHA256"];
    [str appendFormat:@"&SignatureVersion=2"];
    [str appendFormat:@"&Timestamp=%@", [[formatter stringFromDate:[NSDate date]] stringByEscapingURLCharacters]];
    [str appendFormat:@"&TopicArn=%@", [theTopicArn stringByEscapingURLCharacters]];
    
    NSURL *url = [NSURL URLWithString:str];
    NSAssert(url != nil, @"url may not be nil!");
    NSString *signature = [sap signatureForHTTPMethod:@"GET" url:url];
    [str appendFormat:@"&Signature=%@", [signature stringByEscapingURLCharacters]];
    
    NSURL *urlWithSignature = [NSURL URLWithString:str];
    AWSQueryRequest *req = [[[AWSQueryRequest alloc] initWithMethod:@"GET" url:urlWithSignature retryOnTransientError:retryOnTransientError] autorelease];
    AWSQueryResponse *response = [req execute:error];
    if (response == nil) {
        return nil;
    }
    SubscribeResponse *sr = [[[SubscribeResponse alloc] initWithData:[response body]] autorelease];
    NSString *subscriptionArn = [sr subscriptionArn];
    if (subscriptionArn == nil) {
        SETNSERROR([SNS errorDomain], -1, @"SubscriptionArn not found in Subscribe response");
    }
    return subscriptionArn;
}
- (NSArray *)topicArns:(NSError **)error {
    NSDateFormatter *formatter = [[[NSDateFormatter alloc] init] autorelease];
    [formatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss'Z'"];
    [formatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
    
    NSMutableString *str = [NSMutableString stringWithFormat:@"%@/?", [awsRegion snsEndpointWithSSL:NO]];
    [str appendFormat:@"AWSAccessKeyId=%@", [accessKey stringByEscapingURLCharacters]];
    [str appendFormat:@"&Action=ListTopics"];
    [str appendFormat:@"&SignatureMethod=HmacSHA256"];
    [str appendFormat:@"&SignatureVersion=2"];
    [str appendFormat:@"&Timestamp=%@", [[formatter stringFromDate:[NSDate date]] stringByEscapingURLCharacters]];
    NSURL *url = [NSURL URLWithString:str];
    NSAssert(url != nil, @"url may not be nil!");
    NSString *signature = [sap signatureForHTTPMethod:@"GET" url:url];
    [str appendFormat:@"&Signature=%@", [signature stringByEscapingURLCharacters]];
    
    NSURL *urlWithSignature = [NSURL URLWithString:str];
    AWSQueryRequest *req = [[[AWSQueryRequest alloc] initWithMethod:@"GET" url:urlWithSignature retryOnTransientError:retryOnTransientError] autorelease];
    AWSQueryResponse *response = [req execute:error];
    if (response == nil) {
        return nil;
    }
    ListTopicsResponse *ltr = [[[ListTopicsResponse alloc] initWithData:[response body]] autorelease];
    return [ltr topicArns];
}
- (BOOL)deleteTopicWithArn:(NSString *)theTopicArn error:(NSError **)error {
    NSDateFormatter *formatter = [[[NSDateFormatter alloc] init] autorelease];
    [formatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss'Z'"];
    [formatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
    
    NSMutableString *str = [NSMutableString stringWithFormat:@"%@/?", [awsRegion snsEndpointWithSSL:NO]];
    [str appendFormat:@"AWSAccessKeyId=%@", [accessKey stringByEscapingURLCharacters]];
    [str appendFormat:@"&Action=DeleteTopic"];
    //    [str appendFormat:@"&Expires=%ld", (NSUInteger)[[[NSDate date] dateByAddingTimeInterval:30.0] timeIntervalSince1970]];
    [str appendFormat:@"&SignatureMethod=HmacSHA256"];
    [str appendFormat:@"&SignatureVersion=2"];
    [str appendFormat:@"&Timestamp=%@", [[formatter stringFromDate:[NSDate date]] stringByEscapingURLCharacters]];
    [str appendFormat:@"&TopicArn=%@", [theTopicArn stringByEscapingURLCharacters]];
    NSURL *url = [NSURL URLWithString:str];
    NSAssert(url != nil, @"url may not be nil!");
    NSString *signature = [sap signatureForHTTPMethod:@"GET" url:url];
    [str appendFormat:@"&Signature=%@", [signature stringByEscapingURLCharacters]];
    
    NSURL *urlWithSignature = [NSURL URLWithString:str];
    AWSQueryRequest *req = [[[AWSQueryRequest alloc] initWithMethod:@"GET" url:urlWithSignature retryOnTransientError:retryOnTransientError] autorelease];
    AWSQueryResponse *response = [req execute:error];
    if (response == nil) {
        return NO;
    }
    return YES;
}
@end
