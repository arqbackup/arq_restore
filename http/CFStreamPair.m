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
#import <SystemConfiguration/SystemConfiguration.h>
#import "CFStreamPair.h"
#import "CFStreamInputStream.h"
#import "CFStreamOutputStream.h"
#import "DNS_SDErrors.h"

static uint32_t HTTP_PORT = 80;
static uint32_t HTTPS_PORT = 443;

@implementation CFStreamPair
+ (NSString *)errorDomain {
    return @"CFStreamPairErrorDomain";
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
    return [NSError errorWithDomain:[CFStreamPair errorDomain] code:code userInfo:[NSDictionary dictionaryWithObjectsAndKeys:localizedDescription, NSLocalizedDescriptionKey, nil]];
}
- (id)initWithHost:(NSString *)theHost useSSL:(BOOL)isUseSSL maxLifetime:(NSTimeInterval)theMaxLifetime {
    if (self = [super init]) {
        description = [[NSString alloc] initWithFormat:@"<CFStreamPair host=%@ ssl=%@>", theHost, (isUseSSL ? @"YES" : @"NO")];
        CFReadStreamRef readStream;
        CFWriteStreamRef writeStream;
        CFStreamCreatePairWithSocketToHost(kCFAllocatorDefault, (CFStringRef)theHost, (isUseSSL ? HTTPS_PORT : HTTP_PORT), &readStream, &writeStream);
        if (isUseSSL) {
            NSDictionary *sslProperties = [NSDictionary dictionaryWithObjectsAndKeys:
                                           (NSString *)kCFStreamSocketSecurityLevelNegotiatedSSL, kCFStreamSSLLevel,
                                           kCFBooleanTrue, kCFStreamSSLAllowsExpiredCertificates,
                                           kCFBooleanTrue, kCFStreamSSLAllowsExpiredRoots,
                                           kCFBooleanTrue, kCFStreamSSLAllowsAnyRoot,
                                           kCFBooleanFalse, kCFStreamSSLValidatesCertificateChain,
                                           kCFNull, kCFStreamSSLPeerName,
                                           nil];
            
            CFReadStreamSetProperty(readStream, kCFStreamPropertySSLSettings, sslProperties);
            CFWriteStreamSetProperty(writeStream, kCFStreamPropertySSLSettings, sslProperties);
        }
        NSDictionary *proxyDict = (NSDictionary *)SCDynamicStoreCopyProxies(NULL);
        if ([proxyDict objectForKey:(NSString *)kCFStreamPropertyHTTPProxyHost] != nil) {
            CFReadStreamSetProperty(readStream, kCFStreamPropertyHTTPProxy, proxyDict);
            CFWriteStreamSetProperty(writeStream, kCFStreamPropertyHTTPProxy, proxyDict);
        }
        if ([proxyDict objectForKey:(NSString *)kCFStreamPropertySOCKSProxyHost] != nil && [proxyDict objectForKey:(NSString *)kCFStreamPropertySOCKSProxyPort] != nil) {
            CFReadStreamSetProperty(readStream, kCFStreamPropertySOCKSProxy, proxyDict);
            CFWriteStreamSetProperty(writeStream, kCFStreamPropertySOCKSProxy, proxyDict);
        }
        [proxyDict release];
        
        is = [[CFStreamInputStream alloc] initWithCFReadStream:readStream];
        os = [[CFStreamOutputStream alloc] initWithCFWriteStream:writeStream];
        CFRelease(readStream);
        CFRelease(writeStream);
        createTime = [NSDate timeIntervalSinceReferenceDate];
        maxLifetime = theMaxLifetime;
    }
    return self;
}
- (void)dealloc {
    [description release];
    [is release];
    [os release];
    [super dealloc];
}
- (void)setCloseRequested {
    closeRequested = YES;
}
- (BOOL)isUsable {
    if (closeRequested) {
        HSLogTrace(@"%@ close requested; not reusing", self);
        return NO;
    }
    if (([NSDate timeIntervalSinceReferenceDate] - createTime) > maxLifetime) {
        HSLogTrace(@"%@ > %f seconds old; not reusing", self, maxLifetime);
        return NO;
    }
    return YES;
}

#pragma mark BufferedInputStream
- (unsigned char *)readExactly:(NSUInteger)exactLength error:(NSError **)error {
    return [is readExactly:exactLength error:error];
}
- (unsigned char *)readMaximum:(NSUInteger)maximum length:(NSUInteger *)length error:(NSError **)error {
    return [is readMaximum:maximum length:length error:error];
}
- (uint64_t)bytesReceived {
    return [is bytesReceived];
}
- (unsigned char *)read:(NSUInteger *)length error:(NSError **)error {
    return [is read:length error:error];
}
- (NSData *)slurp:(NSError **)error {
    return [is slurp:error];
}

#pragma mark OutputStream
- (BOOL)write:(const unsigned char *)buf length:(NSUInteger)len error:(NSError **)error {
    NSError *myError = nil;
    BOOL ret = [os write:buf length:len error:&myError];
    if (error != NULL) {
        *error = myError;
    }
    if (!ret && [[myError domain] isEqualToString:@"UnixErrorDomain"] && [myError code] == EPIPE) {
        HSLogError(@"broken pipe"); //FIXME: This may not work with CFStream stuff.
    }
    return ret;
}
- (unsigned long long)bytesWritten {
    return [os bytesWritten];
}

#pragma mark NSObject
- (NSString *)description {
    return description;
}
@end
