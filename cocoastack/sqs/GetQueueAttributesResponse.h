//
//  GetQueueAttributesResponse.h
//  Arq
//
//  Created by Stefan Reitshamer on 9/17/12.
//
//


@interface GetQueueAttributesResponse : NSObject <NSXMLParserDelegate> {
    BOOL inAttribute;
    NSMutableString *currentStringBuffer;
    NSString *lastAttributeName;
    NSString *queueArn;
}
- (id)initWithData:(NSData *)theData;
- (NSString *)queueArn;
@end
