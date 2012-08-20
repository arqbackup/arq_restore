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

#import <Security/Security.h>
#import <Security/SecCertificate.h>
#import "NSError_extra.h"
#import "NSErrorCodes.h"


@implementation NSError (extra)
+ (NSError *)errorWithDomain:(NSString *)domain code:(NSInteger)code description:(NSString *)theDescription {
    if (theDescription == nil) {
        theDescription = @"(missing description)";
    }
    return [NSError errorWithDomain:domain code:code userInfo:[NSDictionary dictionaryWithObject:theDescription forKey:NSLocalizedDescriptionKey]];
}
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
            || [self code] == EHOSTUNREACH
            || [self code] == EHOSTDOWN
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
- (void)logSSLCerts {
    NSArray *certs = [[self userInfo] objectForKey:@"NSErrorPeerCertificateChainKey"];
    for (NSUInteger index = 0; index < [certs count]; index++) {
        SecCertificateRef secCert = (SecCertificateRef)[certs objectAtIndex:index];
        CFStringRef commonName = NULL;
        if (SecCertificateCopyCommonName(secCert, &commonName) == 0 && commonName != NULL) {
            HSLog(@"SSL cert common name: %@", (NSString *)commonName);
            CFRelease(commonName);
        } else {
            HSLog(@"error getting SSL cert's common name");
        }
        SecKeyRef key = NULL;
        if (SecCertificateCopyPublicKey(secCert, &key) == 0 && key != NULL) {
            CSSM_CSP_HANDLE cspHandle;
            if (SecKeyGetCSPHandle(key, &cspHandle) == 0) {
                HSLog(@"SSL cert CSP handle: %d", (long)cspHandle);
            } else {
                HSLog(@"error getting SSL cert's key's CSP handle");
            }
            const CSSM_KEY *cssmKey;
            if (SecKeyGetCSSMKey(key, &cssmKey) == 0) {
                NSData *keyHeaderData = [NSData dataWithBytes:(const unsigned char *)&(cssmKey->KeyHeader) length:sizeof(CSSM_KEYHEADER)];
                HSLog(@"SSL cert CSSM key header: %@", keyHeaderData);
                NSData *keyData = [NSData dataWithBytes:(const unsigned char *)cssmKey->KeyData.Data length:cssmKey->KeyData.Length];
                HSLog(@"SSL cert CSSM key data: %@", keyData);
            } else {
                HSLog(@"error getting SSL cert's key's CSM key");
            }
            CFRelease(key);
        } else {
            HSLog(@"error getting SSL cert's public key");
        }
    }
}
@end
