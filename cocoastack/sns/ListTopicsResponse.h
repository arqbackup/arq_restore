//
//  ListTopicsResponse.h
//  Arq
//
//  Created by Stefan Reitshamer on 9/29/12.
//
//


@interface ListTopicsResponse : NSObject <NSXMLParserDelegate> {
    NSMutableArray *topicArns;
    NSMutableString *currentStringBuffer;
}
- (id)initWithData:(NSData *)theData;
- (NSArray *)topicArns;
@end
