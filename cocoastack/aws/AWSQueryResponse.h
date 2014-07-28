//
//  Created by Stefan Reitshamer on 9/16/12.
//
//


@interface AWSQueryResponse : NSObject {
    int code;
    NSDictionary *headers;
    NSData *body;
}
- (id)initWithCode:(int)theCode headers:(NSDictionary *)theHeaders body:(NSData *)theBody;

- (int)code;
- (NSString *)headerForKey:(NSString *)theKey;
- (NSData *)body;
@end
