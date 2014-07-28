//
//  NSErrorIO.m
//  Arq
//
//  Created by Stefan Reitshamer on 6/5/13.
//  Copyright (c) 2013 Stefan Reitshamer. All rights reserved.
//

#import "NSErrorIO.h"
#import "BooleanIO.h"
#import "StringIO.h"
#import "IntegerIO.h"


@implementation NSErrorIO
+ (BOOL)write:(NSError *)theError to:(BufferedOutputStream *)theBOS error:(NSError **)error {
    if (![BooleanIO write:(theError != nil) to:theBOS error:error]) {
        return NO;
    }
    if (theError != nil) {
        if (![StringIO write:[theError domain] to:theBOS error:error]
            || ![IntegerIO writeInt64:[theError code] to:theBOS error:error]
            || ![StringIO write:[theError localizedDescription] to:theBOS error:error]) {
            return NO;
        }
    }
    return YES;
}
+ (BOOL)read:(NSError **)theError from:(BufferedInputStream *)theBIS error:(NSError **)error {
    if (theError != NULL) {
        *theError = nil;
    }
    BOOL isNotNil = NO;
    if (![BooleanIO read:&isNotNil from:theBIS error:error]) {
        return NO;
    }
    if (isNotNil) {
        NSString *domain = nil;
        int64_t code = 0;
        NSString *description = nil;
        if (![StringIO read:&domain from:theBIS error:error]
            || ![IntegerIO readInt64:&code from:theBIS error:error]
            || ![StringIO read:&description from:theBIS error:error]) {
            return NO;
        }
        if (theError != NULL) {
            *theError = [NSError errorWithDomain:domain code:(NSInteger)code description:description];
        }
    }
    return YES;
}
@end
