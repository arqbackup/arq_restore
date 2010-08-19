//
//  NSError_extra.h
//  Arq
//
//  Created by Stefan Reitshamer on 6/29/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSError (extra)
- (BOOL)isErrorWithDomain:(NSString *)theDomain code:(int)theCode;
@end
