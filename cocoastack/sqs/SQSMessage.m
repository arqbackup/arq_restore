//
//  SQSMessage.m
//  Arq
//
//  Created by Stefan Reitshamer on 9/17/12.
//
//

#import "SQSMessage.h"

@implementation SQSMessage
- (id)initWithQueueURL:(NSURL *)theQueueURL body:(NSString *)theBody receiptHandle:(NSString *)theReceiptHandle {
    if (self = [super init]) {
        queueURL = [theQueueURL retain];
        body = [theBody retain];
        receiptHandle = [theReceiptHandle retain];
    }
    return self;
}
- (void)dealloc {
    [queueURL release];
    [body release];
    [receiptHandle release];
    [super dealloc];
}

- (NSURL *)queueURL {
    return queueURL;
}
- (NSString *)body {
    return body;
}
- (NSString *)receiptHandle {
    return receiptHandle;
}
@end
