/*
 Copyright (c) 2009-2017, Haystack Software LLC https://www.arqbackup.com
 
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



#import <Security/Security.h>
#import <Security/SecCertificate.h>
#import "NSError_extra.h"
#import "S3Service.h"


@implementation NSError (extra)
- (id)initWithDomain:(NSString *)domain code:(NSInteger)code description:(NSString *)theDescription {
    if (theDescription == nil) {
        theDescription = @"(missing description)";
    }
    return [self initWithDomain:domain code:code userInfo:[NSDictionary dictionaryWithObject:theDescription forKey:NSLocalizedDescriptionKey]];
}
- (BOOL)isErrorWithDomain:(NSString *)theDomain code:(int)theCode {
    return [self code] == theCode && [[self domain] isEqualToString:theDomain];
}
- (BOOL)isConnectionResetError {
    if ([[self domain] isEqualToString:@"UnixErrorDomain"] || [[self domain] isEqualToString:@"NSPOSIXErrorDomain"]) {
        if ([self code] == ENETRESET
            || [self code] == ECONNRESET) {
            return YES;
        }
    }
    return NO;
}
- (BOOL)isTransientError {
    if ([[self domain] isEqualToString:@"UnixErrorDomain"] || [[self domain] isEqualToString:@"NSPOSIXErrorDomain"]) {
        if ([self code] == ENETDOWN
            || [self code] == EADDRNOTAVAIL
            || [self code] == ENETUNREACH
            || [self code] == ENETRESET
            || [self code] == ECONNABORTED
            || [self code] == ECONNRESET
            || [self code] == EISCONN
            || [self code] == ENOTCONN
            || [self code] == ETIMEDOUT
            || [self code] == ECONNREFUSED
            || [self code] == EHOSTDOWN
            || [self code] == EHOSTUNREACH
            || [self code] == EPIPE) {
            return YES;
        }
    }
    if ([[self domain] isEqualToString:(NSString *)kCFErrorDomainCFNetwork]) {
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
    if ([[self domain] isEqualToString:[S3Service errorDomain]] && [self code] == S3SERVICE_ERROR_AMAZON_ERROR) {
        return YES;
    }
    if ([[self domain] isEqualToString:@"NSOSStatusErrorDomain"] && [self code] <= errSSLProtocol && [self code] >= errSSLLast) {
        return YES;
    }
    if ([self isSSLError]) {
        return YES;
    }
    if ([self code] == ERROR_TIMEOUT) {
        return YES;
    }
    
    HSLogDebug(@"%@ not a transient error", self);
    return NO;
}
- (BOOL)isSSLError {
    return [[self domain] isEqualToString:NSURLErrorDomain]
    && [self code] <= NSURLErrorSecureConnectionFailed
    && [self code] >= NSURLErrorClientCertificateRejected;
}
@end
