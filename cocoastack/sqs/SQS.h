//
//  SQS.h
//  Arq
//
//  Created by Stefan Reitshamer on 9/16/12.
//
//

@class SignatureV2Provider;
@class AWSRegion;
@class ReceiveMessageResponse;


@interface SQS : NSObject {
    NSString *accessKey;
    SignatureV2Provider *sap;
    AWSRegion *awsRegion;
    BOOL retryOnTransientError;
}
+ (NSString *)errorDomain;

- (id)initWithAccessKey:(NSString *)access secretKey:(NSString *)secret awsRegion:(AWSRegion *)theAWSRegion retryOnTransientError:(BOOL)retry;

- (NSURL *)createQueueWithName:(NSString *)theName error:(NSError **)error;
- (NSString *)queueArnForQueueURL:(NSURL *)theURL error:(NSError **)error;
- (BOOL)setSendMessagePermissionToQueueURL:(NSURL *)theQueueURL queueArn:(NSString *)theQueueArn forSourceArn:(NSString *)theSourceArn error:(NSError **)error;
- (ReceiveMessageResponse *)receiveMessagesForQueueURL:(NSURL *)theURL maxMessages:(NSUInteger)theMaxMessages error:(NSError **)error;
- (BOOL)deleteMessageWithQueueURL:(NSURL *)theURL receiptHandle:(NSString *)theReceiptHandle error:(NSError **)error;
- (NSArray *)queueURLs:(NSError **)error;
- (BOOL)deleteQueue:(NSURL *)theQueueURL error:(NSError **)error;
@end
