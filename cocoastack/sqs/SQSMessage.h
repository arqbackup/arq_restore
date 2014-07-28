//
//  SQSMessage.h
//  Arq
//
//  Created by Stefan Reitshamer on 9/17/12.
//
//


@interface SQSMessage : NSObject {
    NSURL *queueURL;
    NSString *body;
    NSString *receiptHandle;
}
- (id)initWithQueueURL:(NSURL *)theQueueURL body:(NSString *)theBody receiptHandle:(NSString *)theReceiptHandle;

- (NSURL *)queueURL;
- (NSString *)body;
- (NSString *)receiptHandle;
@end
