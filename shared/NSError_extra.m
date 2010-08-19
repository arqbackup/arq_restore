//
//  NSError_extra.m
//  Arq
//
//  Created by Stefan Reitshamer on 6/29/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "NSError_extra.h"


@implementation NSError (extra)
- (BOOL)isErrorWithDomain:(NSString *)theDomain code:(int)theCode {
    return [self code] == theCode && [[self domain] isEqualToString:theDomain];
}
@end
