//
//  GlacierResponse.h
//  Arq
//
//  Created by Stefan Reitshamer on 9/11/12.
//
//


@interface GlacierResponse : NSObject {
    int code;
    NSMutableDictionary *headers;
    NSData *body;
}
- (id)initWithCode:(int)theCode headers:(NSDictionary *)theHeaders body:(NSData *)theBody;

- (int)code;
- (NSDictionary *)headers;
- (NSString *)headerForKey:(NSString *)theKey;
- (NSData *)body;
@end
