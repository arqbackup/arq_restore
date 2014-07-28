//
//  SubscribeResponse.h
//  Arq
//
//  Created by Stefan Reitshamer on 9/17/12.
//
//


@interface SubscribeResponse : NSObject <NSXMLParserDelegate> {
    NSString *subscriptionArn;
    NSMutableString *currentStringBuffer;
}
- (id)initWithData:(NSData *)theData;
- (NSString *)subscriptionArn;
@end
