//
//  SQSMessage.h
//  Arq
//
//  Created by Stefan Reitshamer on 9/17/12.
//
//


@interface ReceiveMessageResponse : NSObject <NSXMLParserDelegate> {
    NSURL *queueURL;
    NSMutableArray *messages;
    NSMutableString *currentStringBuffer;
    BOOL inMessage;
    NSString *receiptHandle;
    NSString *body;
}
- (id)initWithQueueURL:(NSURL *)theQueueURL data:(NSData *)theData;
- (NSArray *)messages;
@end
