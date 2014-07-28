//
//  CreateQueueResponse.h
//
//  Created by Stefan Reitshamer on 9/16/12.
//
//


@interface CreateQueueResponse : NSObject <NSXMLParserDelegate> {
    NSMutableString *currentStringBuffer;
    NSURL *queueURL;
}
- (id)initWithData:(NSData *)theData;
- (NSURL *)queueURL;
@end
