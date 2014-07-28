//
//  Created by Stefan Reitshamer on 9/16/12.
//
//

#import "AWSQueryResponse.h"

@implementation AWSQueryResponse
- (id)initWithCode:(int)theCode headers:(NSDictionary *)theHeaders body:(NSData *)theBody {
    if (self = [super init]) {
        code = theCode;
        headers = [theHeaders copy];
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
- (NSString *)headerForKey:(NSString *)theKey {
    return [headers objectForKey:theKey];
}
- (NSData *)body {
    return body;
}

@end
