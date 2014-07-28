//
//  AmazonErrorResult.h
//
//  Created by Stefan Reitshamer on 3/9/12.
//  Copyright (c) 2012 Haystack Software. All rights reserved.
//


@interface S3ErrorResult : NSObject <NSXMLParserDelegate> {
    NSMutableDictionary *values;
    NSMutableString *currentStringBuffer;
    BOOL errorOccurred;
    NSError *amazonError;
}
- (id)initWithAction:(NSString *)theAction data:(NSData *)theData httpErrorCode:(int)theHTTPStatusCode;

- (NSError *)error;
@end
