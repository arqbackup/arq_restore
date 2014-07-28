//
//  Created by Stefan Reitshamer on 9/16/12.
//
//


@interface AWSQueryError : NSObject <NSXMLParserDelegate> {
    NSMutableDictionary *values;
    NSMutableString *currentStringBuffer;
    BOOL parseErrorOccurred;
    NSError *nsError;
}
- (id)initWithDomain:(NSString *)theDomain httpStatusCode:(int)theCode responseBody:(NSData *)theBody;
- (NSError *)nsError;
@end
