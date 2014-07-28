//
//  SNS.m
//  Arq
//
//  Created by Stefan Reitshamer on 9/16/12.
//
//

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
