/*
 Copyright (c) 2009-2014, Stefan Reitshamer http://www.haystacksoftware.com
 
 All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 
 * Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in the
 documentation and/or other materials provided with the distribution.
 
 * Neither the names of PhotoMinds LLC or Haystack Software, nor the names of
 their contributors may be used to endorse or promote products derived from
 this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
 TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */


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
