//
//  S3MultiDeleteResponse.h
//  Arq
//
//  Created by Stefan Reitshamer on 1/13/14.
//  Copyright (c) 2014 Stefan Reitshamer. All rights reserved.
//


@interface S3MultiDeleteResponse : NSObject <NSXMLParserDelegate> {
    NSMutableArray *elementNames;
    NSMutableString *currentStringBuffer;
    NSString *errorKey;
    NSString *errorCode;
    NSString *errorMessage;
    NSMutableDictionary *errorCodesByPath;
}
- (id)initWithData:(NSData *)theData;

- (NSDictionary *)errorCodesByPath;
@end
