//
//  SNS.h
//  Arq
//
//  Created by Stefan Reitshamer on 9/16/12.
//
//

@class SignatureV2Provider;
@class AWSRegion;


@interface SNS : NSObject {
    NSString *accessKey;
    SignatureV2Provider *sap;
    AWSRegion *awsRegion;
    BOOL retryOnTransientError;
}
+ (NSString *)errorDomain;

- (id)initWithAccessKey:(NSString *)access secretKey:(NSString *)secret awsRegion:(AWSRegion *)theAWSRegion retryOnTransientError:(BOOL)retry;

- (NSString *)createTopic:(NSString *)theName error:(NSError **)error;
- (NSString *)subscribeQueueArn:(NSString *)theQueueArn toTopicArn:(NSString *)theTopicArn error:(NSError **)error;
- (NSArray *)topicArns:(NSError **)error;
- (BOOL)deleteTopicWithArn:(NSString *)theTopicArn error:(NSError **)error;
@end
