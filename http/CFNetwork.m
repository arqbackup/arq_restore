/*
 Copyright (c) 2009-2010, Stefan Reitshamer http://www.haystacksoftware.com
 
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

#include <sys/types.h>
#include <sys/socket.h>
#include <netdb.h>
#import "CFNetwork.h"
#import "DNS_SDErrors.h"

@implementation CFNetwork
+ (NSString *)errorDomain {
    return @"CFNetworkErrorDomain";
}
+ (NSError *)NSErrorWithNetworkError:(CFErrorRef)err {
    NSString *localizedDescription = @"Network error";
    NSString *domain = (NSString *)CFErrorGetDomain(err);
    CFIndex code = CFErrorGetCode(err);
    CFDictionaryRef userInfo = CFErrorCopyUserInfo(err);
    if ([domain isEqualToString:(NSString *)kCFErrorDomainCFNetwork]) {
        if (code == kCFHostErrorHostNotFound) {
            localizedDescription = @"host not found";
        } else if (code == kCFHostErrorUnknown) {
            int gaiCode = 0;
            if (CFNumberGetValue((CFNumberRef)CFDictionaryGetValue(userInfo, kCFGetAddrInfoFailureKey), kCFNumberIntType, &gaiCode)) {
                HSLogDebug(@"Host lookup error: %s", gai_strerror(gaiCode));
                localizedDescription = @"Could not connect to the Internet";
            }
        } else if (code == kCFSOCKSErrorUnknownClientVersion) {
            localizedDescription = @"Unknown SOCKS client version";
        } else if (code == kCFSOCKSErrorUnsupportedServerVersion) {
            localizedDescription = [NSString stringWithFormat:@"Unsupported SOCKS server version (server requested version %@)", (NSString *)CFDictionaryGetValue(userInfo, kCFSOCKSVersionKey)];
        } else if (code == kCFSOCKS4ErrorRequestFailed) {
            localizedDescription = @"SOCKS4 request rejected or failed";
        } else if (code == kCFSOCKS4ErrorIdentdFailed) {
            localizedDescription = @"SOCKS4 server cannot connect to identd on the client";
        } else if (code == kCFSOCKS4ErrorIdConflict) {
            localizedDescription = @"SOCKS4 client and identd report different user IDs";
        } else if (code == kCFSOCKS4ErrorUnknownStatusCode) {
            localizedDescription = [NSString stringWithFormat:@"SOCKS4 error %@", (NSString *)CFDictionaryGetValue(userInfo, kCFSOCKSStatusCodeKey)];
        } else if (code == kCFSOCKS5ErrorBadState) {
            localizedDescription = @"SOCKS5 bad state";
        } else if (code == kCFSOCKS5ErrorBadResponseAddr) {
            localizedDescription = @"SOCKS5 bad credentials";
        } else if (code == kCFSOCKS5ErrorBadCredentials) {
            localizedDescription = @"SOCKS5 unsupported negotiation method";
        } else if (code == kCFSOCKS5ErrorUnsupportedNegotiationMethod) {
            localizedDescription = @"SOCKS5 unsupported negotiation method";
        } else if (code == kCFSOCKS5ErrorNoAcceptableMethod) {
            localizedDescription = @"SOCKS5 no acceptable method";
        } else if (code == kCFNetServiceErrorUnknown) {
            localizedDescription = @"Unknown Net Services error";
        } else if (code == kCFNetServiceErrorCollision) {
            localizedDescription = @"Net Services: collision";
        } else if (code == kCFNetServiceErrorNotFound) {
            localizedDescription = @"Net Services: not found";
        } else if (code == kCFNetServiceErrorInProgress) {
            localizedDescription = @"Net Services: in progress";
        } else if (code == kCFNetServiceErrorBadArgument) {
            localizedDescription = @"Net Services: bad argument";
        } else if (code == kCFNetServiceErrorCancel) {
            localizedDescription = @"Net Services: cancelled";
        } else if (code == kCFNetServiceErrorInvalid) {
            localizedDescription = @"Net Services: invalid";
        } else if (code == kCFNetServiceErrorTimeout) {
            localizedDescription = @"Net Services timeout";
        } else if (code == kCFNetServiceErrorDNSServiceFailure) {
            localizedDescription = @"Net Services DNS failure";
            int dns_sdCode = 0;
            if (CFNumberGetValue((CFNumberRef)CFDictionaryGetValue(userInfo, kCFDNSServiceFailureKey), kCFNumberIntType, &dns_sdCode)) {
                localizedDescription = [NSString stringWithFormat:@"Net Services DNS failure: %@", [DNS_SDErrors descriptionForDNS_SDError:dns_sdCode]];
            }
        } else if (code == kCFFTPErrorUnexpectedStatusCode) {
            localizedDescription = [NSString stringWithFormat:@"FTP error %@", (NSString *)CFDictionaryGetValue(userInfo, kCFFTPStatusCodeKey)];
        } else if (code == kCFErrorHTTPAuthenticationTypeUnsupported) {
            localizedDescription = @"HTTP authentication type unsupported";
        } else if (code == kCFErrorHTTPBadCredentials) {
            localizedDescription = @"bad HTTP credentials";
        } else if (code == kCFErrorHTTPConnectionLost) {
            localizedDescription = @"HTTP connection lost";
        } else if (code == kCFErrorHTTPParseFailure) {
            localizedDescription = @"HTTP parse failure";
        } else if (code == kCFErrorHTTPRedirectionLoopDetected) {
            localizedDescription = @"HTTP redirection loop detected";
        } else if (code == kCFErrorHTTPBadURL) {
            localizedDescription = @"bad HTTP URL";
        } else if (code == kCFErrorHTTPProxyConnectionFailure) {
            localizedDescription = @"HTTP proxy connection failure";
        } else if (code == kCFErrorHTTPBadProxyCredentials) {
            localizedDescription = @"bad HTTP proxy credentials";
        } else if (code == kCFErrorPACFileError) {
            localizedDescription = @"HTTP PAC file error";
        }
    } else if ([domain isEqualToString:@"NSPOSIXErrorDomain"] && code == ENOTCONN) {
        localizedDescription = @"Lost connection to the Internet";
    } else {
        localizedDescription = [(NSString *)CFErrorCopyDescription(err) autorelease];
    }
    CFRelease(userInfo);
    return [NSError errorWithDomain:[CFNetwork errorDomain] code:code userInfo:[NSDictionary dictionaryWithObjectsAndKeys:localizedDescription, NSLocalizedDescriptionKey, nil]];
}
@end
