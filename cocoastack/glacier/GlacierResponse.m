//
//  GlacierResponse.m
//  Arq
//
//  Created by Stefan Reitshamer on 9/11/12.
//
//

#import "GlacierResponse.h"

@implementation GlacierResponse
- (id)initWithCode:(int)theCode headers:(NSDictionary *)theHeaders body:(NSData *)theBody {
    if (self = [super init]) {
        code = theCode;
        headers = [[NSMutableDictionary alloc] init];
        for (NSString *key in [theHeaders allKeys]) {
            [headers setObject:[theHeaders objectForKey:key] forKey:[key lowercaseString]];
        }
        body = [theBody retain];
    }
    return self;
}
- (void)dealloc {
    [headers release];
    [body release];
    [super dealloc];
}


- (int)code {
    return code;
}
- (NSDictionary *)headers {
    return headers;
}
- (NSString *)headerForKey:(NSString *)theKey {
    return [headers objectForKey:[theKey lowercaseString]];
}
- (NSData *)body {
    return body;
}
@end
