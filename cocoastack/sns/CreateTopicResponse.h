//
//  CreateTopicResponse.h
//
//  Created by Stefan Reitshamer on 9/16/12.
//
//


@interface CreateTopicResponse : NSObject <NSXMLParserDelegate> {
    NSString *topicArn;
    NSMutableString *currentStringBuffer;
}
- (id)initWithData:(NSData *)theData;
- (NSString *)topicArn;
@end
