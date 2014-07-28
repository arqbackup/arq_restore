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


#import "SQS.h"
#import "SignatureV2Provider.h"
#import "AWSRegion.h"
#import "NSString_extra.h"
#import "AWSQueryRequest.h"
#import "AWSQueryResponse.h"
#import "CreateQueueResponse.h"
#import "GetQueueAttributesResponse.h"
#import "ReceiveMessageResponse.h"
#import "ListQueuesResponse.h"


@implementation SQS
+ (NSString *)errorDomain {
    return @"SQSErrorDomain";
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

- (NSURL *)createQueueWithName:(NSString *)theName error:(NSError **)error {
    NSDateFormatter *formatter = [[[NSDateFormatter alloc] init] autorelease];
    [formatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss'Z'"];
    [formatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
    
    NSMutableString *str = [NSMutableString stringWithFormat:@"%@/?", [awsRegion sqsEndpointWithSSL:NO]];
    [str appendFormat:@"AWSAccessKeyId=%@", [accessKey stringByEscapingURLCharacters]];
    [str appendFormat:@"&Action=CreateQueue"];
    //    [str appendFormat:@"&Expires=%ld", (NSUInteger)[[[NSDate date] dateByAddingTimeInterval:30.0] timeIntervalSince1970]];
    [str appendFormat:@"&QueueName=%@", [theName stringByEscapingURLCharacters]];
    [str appendFormat:@"&SignatureMethod=HmacSHA256"];
    [str appendFormat:@"&SignatureVersion=2"];
    [str appendFormat:@"&Timestamp=%@", [[formatter stringFromDate:[NSDate date]] stringByEscapingURLCharacters]];
    [str appendFormat:@"&Version=2011-10-01"];
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
    CreateQueueResponse *cqr = [[[CreateQueueResponse alloc] initWithData:[response body]] autorelease];
    NSURL *ret = [cqr queueURL];
    if (ret == nil) {
        SETNSERROR([SQS errorDomain], -1, @"QueueURL not found in CreateQueue response");
    }
    return ret;
}
- (NSString *)queueArnForQueueURL:(NSURL *)theURL error:(NSError **)error {
    NSDateFormatter *formatter = [[[NSDateFormatter alloc] init] autorelease];
    [formatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss'Z'"];
    [formatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
    
    NSMutableString *str = [NSMutableString stringWithFormat:@"%@?", [theURL description]];
    [str appendFormat:@"AWSAccessKeyId=%@", [accessKey stringByEscapingURLCharacters]];
    [str appendFormat:@"&Action=GetQueueAttributes"];
    [str appendFormat:@"&AttributeName.1=QueueArn"];
    //    [str appendFormat:@"&Expires=%ld", (NSUInteger)[[[NSDate date] dateByAddingTimeInterval:30.0] timeIntervalSince1970]];
    [str appendFormat:@"&SignatureMethod=HmacSHA256"];
    [str appendFormat:@"&SignatureVersion=2"];
    [str appendFormat:@"&Timestamp=%@", [[formatter stringFromDate:[NSDate date]] stringByEscapingURLCharacters]];
    [str appendFormat:@"&Version=2009-02-01"];
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
    
    GetQueueAttributesResponse *gqar = [[[GetQueueAttributesResponse alloc] initWithData:[response body]] autorelease];
    NSString *ret = [gqar queueArn];
    if (ret == nil) {
        SETNSERROR([SQS errorDomain], -1, @"QueueArn not found in GetQueueAttributes response");
    }
    return ret;    
}
- (BOOL)setSendMessagePermissionToQueueURL:(NSURL *)theQueueURL queueArn:(NSString *)theQueueArn forSourceArn:(NSString *)theSourceArn error:(NSError **)error {
    NSString *theQueueName = [[theQueueArn componentsSeparatedByString:@":"] lastObject];
    NSString *policy = [NSString stringWithFormat:@"{\"Statement\": [{\"Sid\": \"%@-policy\", \"Effect\": \"Allow\", \"Principal\": {\"AWS\": \"*\"}, \"Action\": \"sqs:SendMessage\", \"Resource\": \"%@\", \"Condition\": { \"ArnEquals\": { \"aws:sourceArn\": \"%@\" } } }]}", theQueueName, theQueueArn, theSourceArn];
    HSLogDebug(@"policy = %@", policy);
    NSString *escapedPolicy = [(NSString *)CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (CFStringRef)policy, NULL, CFSTR("?=&+?:,*"), kCFStringEncodingUTF8) autorelease];

    NSDateFormatter *formatter = [[[NSDateFormatter alloc] init] autorelease];
    [formatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss'Z'"];
    [formatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
    
    NSMutableString *str = [NSMutableString stringWithFormat:@"%@?", [theQueueURL description]];
    [str appendFormat:@"AWSAccessKeyId=%@", [accessKey stringByEscapingURLCharacters]];
    [str appendFormat:@"&Action=SetQueueAttributes"];
    [str appendFormat:@"&Attribute.Name=Policy"];
    [str appendFormat:@"&Attribute.Value=%@", escapedPolicy];
    [str appendFormat:@"&SignatureMethod=HmacSHA256"];
    [str appendFormat:@"&SignatureVersion=2"];
    [str appendFormat:@"&Timestamp=%@", [[formatter stringFromDate:[NSDate date]] stringByEscapingURLCharacters]];
    [str appendFormat:@"&Version=2009-02-01"];
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
- (ReceiveMessageResponse *)receiveMessagesForQueueURL:(NSURL *)theURL maxMessages:(NSUInteger)theMaxMessages error:(NSError **)error {
    if (theMaxMessages > 10) {
        // SQS only accepts a value between 1 and 10.
        theMaxMessages = 10;
    }
    NSDateFormatter *formatter = [[[NSDateFormatter alloc] init] autorelease];
    [formatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss'Z'"];
    [formatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
    
    NSMutableString *str = [NSMutableString stringWithFormat:@"%@?", [theURL description]];
    [str appendFormat:@"AWSAccessKeyId=%@", [accessKey stringByEscapingURLCharacters]];
    [str appendFormat:@"&Action=ReceiveMessage"];
    [str appendFormat:@"&AttributeName=All"];
    [str appendFormat:@"&MaxNumberOfMessages=%lu", (unsigned long)theMaxMessages];
    [str appendFormat:@"&SignatureMethod=HmacSHA256"];
    [str appendFormat:@"&SignatureVersion=2"];
    [str appendFormat:@"&Timestamp=%@", [[formatter stringFromDate:[NSDate date]] stringByEscapingURLCharacters]];
    [str appendFormat:@"&Version=2009-02-01"];
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
    ReceiveMessageResponse *msg = [[[ReceiveMessageResponse alloc] initWithQueueURL:theURL data:[response body]] autorelease];
    return msg;
}
- (BOOL)deleteMessageWithQueueURL:(NSURL *)theURL receiptHandle:(NSString *)theReceiptHandle error:(NSError **)error {
    NSDateFormatter *formatter = [[[NSDateFormatter alloc] init] autorelease];
    [formatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss'Z'"];
    [formatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
    
    NSMutableString *str = [NSMutableString stringWithFormat:@"%@?", [theURL description]];
    [str appendFormat:@"AWSAccessKeyId=%@", [accessKey stringByEscapingURLCharacters]];
    [str appendFormat:@"&Action=DeleteMessage"];
    [str appendFormat:@"&ReceiptHandle=%@", [theReceiptHandle stringByEscapingURLCharacters]];
    [str appendFormat:@"&SignatureMethod=HmacSHA256"];
    [str appendFormat:@"&SignatureVersion=2"];
    [str appendFormat:@"&Timestamp=%@", [[formatter stringFromDate:[NSDate date]] stringByEscapingURLCharacters]];
    [str appendFormat:@"&Version=2009-02-01"];
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
- (NSArray *)queueURLs:(NSError **)error {
    //FIXME: This only returns up to 1000 queues.
    
    NSDateFormatter *formatter = [[[NSDateFormatter alloc] init] autorelease];
    [formatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss'Z'"];
    [formatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
    
    NSMutableString *str = [NSMutableString stringWithFormat:@"%@/?", [awsRegion sqsEndpointWithSSL:NO]];
    [str appendFormat:@"AWSAccessKeyId=%@", [accessKey stringByEscapingURLCharacters]];
    [str appendFormat:@"&Action=ListQueues"];
    [str appendFormat:@"&SignatureMethod=HmacSHA256"];
    [str appendFormat:@"&SignatureVersion=2"];
    [str appendFormat:@"&Timestamp=%@", [[formatter stringFromDate:[NSDate date]] stringByEscapingURLCharacters]];
    [str appendFormat:@"&Version=2011-10-01"];
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
    ListQueuesResponse *msg = [[[ListQueuesResponse alloc] initWithData:[response body]] autorelease];
    return [msg queueURLs];
}
- (BOOL)deleteQueue:(NSURL *)theQueueURL error:(NSError **)error {
    NSDateFormatter *formatter = [[[NSDateFormatter alloc] init] autorelease];
    [formatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss'Z'"];
    [formatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
    
    NSMutableString *str = [NSMutableString stringWithFormat:@"%@?", [theQueueURL description]];
    [str appendFormat:@"AWSAccessKeyId=%@", [accessKey stringByEscapingURLCharacters]];
    [str appendFormat:@"&Action=DeleteQueue"];
    [str appendFormat:@"&SignatureMethod=HmacSHA256"];
    [str appendFormat:@"&SignatureVersion=2"];
    [str appendFormat:@"&Timestamp=%@", [[formatter stringFromDate:[NSDate date]] stringByEscapingURLCharacters]];
    [str appendFormat:@"&Version=2009-02-01"];
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
