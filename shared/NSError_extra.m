/*
 Copyright (c) 2009-2011, Stefan Reitshamer http://www.haystacksoftware.com
 
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

#import "NSError_extra.h"

@implementation NSError (extra)
+ (NSError *)errorWithDomain:(NSString *)domain code:(NSInteger)code description:(NSString *)theDescription {
    return [NSError errorWithDomain:domain code:code userInfo:[NSDictionary dictionaryWithObject:theDescription forKey:NSLocalizedDescriptionKey]];
}
- (id)initWithDomain:(NSString *)domain code:(NSInteger)code description:(NSString *)theDescription {
    return [self initWithDomain:domain code:code userInfo:[NSDictionary dictionaryWithObject:theDescription forKey:NSLocalizedDescriptionKey]];
}
- (BOOL)isErrorWithDomain:(NSString *)theDomain code:(int)theCode {
    return [self code] == theCode && [[self domain] isEqualToString:theDomain];
}
- (BOOL)isTransientError {
    if ([[self domain] isEqualToString:@"UnixErrorDomain"] && [self code] == ETIMEDOUT) {
        return YES;
    }
    if ([[self domain] isEqualToString:@"NSPOSIXErrorDomain"] && [self code] == ETIMEDOUT) {
        return YES;
    }
    if ([[self domain] isEqualToString:@"NSPOSIXErrorDomain"] && [self code] == ENOTCONN) {
        return YES;
    }
    if ([[self domain] isEqualToString:NSURLErrorDomain]) {
        if ([self code] == NSURLErrorTimedOut
            || [self code] == NSURLErrorCannotFindHost
            || [self code] == NSURLErrorCannotConnectToHost
            || [self code] == NSURLErrorNetworkConnectionLost
            || [self code] == NSURLErrorDNSLookupFailed
            || [self code] == NSURLErrorResourceUnavailable
            || [self code] == NSURLErrorNotConnectedToInternet) {
            return YES;
        }
    }
    HSLogDebug(@"%@ not a transient error", self);
    return NO;
}
@end
