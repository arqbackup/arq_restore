//
//  ListQueuesResponse.h
//  Arq
//
//  Created by Stefan Reitshamer on 10/12/12.
//  Copyright (c) 2012 Stefan Reitshamer. All rights reserved.
//


@interface ListQueuesResponse : NSObject <NSXMLParserDelegate> {
    NSMutableArray *queueURLs;
    NSMutableString *currentStringBuffer;
}
- (id)initWithData:(NSData *)theData;
- (NSArray *)queueURLs;
@end
