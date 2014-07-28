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


#include "libssh2.h"
#include "libssh2_sftp.h"
#import <Security/Security.h>
#import <Security/SecCertificate.h>
#import "NSError_extra.h"
#import "S3Service.h"
#import "GoogleDrive.h"


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
    if ([[self domain] isEqualToString:[GoogleDrive errorDomain]] && [self code] == 500) {
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
    NSNumber *theSessionError = [[self userInfo] objectForKey:@"libssh2SessionError"];
    if (theSessionError != nil) {
        int sessionError = [theSessionError intValue];
        if (sessionError == LIBSSH2_ERROR_SFTP_PROTOCOL) {
            NSNumber *theSFTPError = [[self userInfo] objectForKey:@"libssh2SFTPError"];
            if (theSFTPError != nil) {
                int sftpError = [theSFTPError intValue];
                switch (sftpError) {
                    case LIBSSH2_FX_BAD_MESSAGE:
                    case LIBSSH2_FX_NO_CONNECTION:
                    case LIBSSH2_FX_CONNECTION_LOST:
                        return YES;
                }
            }
        } else {
            switch (sessionError) {
                case LIBSSH2_ERROR_BANNER_RECV:
                case LIBSSH2_ERROR_BANNER_SEND:
                case LIBSSH2_ERROR_INVALID_MAC:
                case LIBSSH2_ERROR_KEX_FAILURE:
                    //            case LIBSSH2_ERROR_ALLOC:
                case LIBSSH2_ERROR_SOCKET_SEND:
                case LIBSSH2_ERROR_KEY_EXCHANGE_FAILURE:
                case LIBSSH2_ERROR_TIMEOUT:
                    //            case LIBSSH2_ERROR_HOSTKEY_INIT:
                    //            case LIBSSH2_ERROR_HOSTKEY_SIGN:
                    //            case LIBSSH2_ERROR_DECRYPT:
                case LIBSSH2_ERROR_SOCKET_DISCONNECT:
                    //            case LIBSSH2_ERROR_PROTO:
                    //            case LIBSSH2_ERROR_PASSWORD_EXPIRED:
                    //            case LIBSSH2_ERROR_FILE:
                    //            case LIBSSH2_ERROR_METHOD_NONE:
                    //            case LIBSSH2_ERROR_AUTHENTICATION_FAILED:
                    //            case LIBSSH2_ERROR_PUBLICKEY_UNVERIFIED:
                case LIBSSH2_ERROR_CHANNEL_OUTOFORDER:
                case LIBSSH2_ERROR_CHANNEL_FAILURE:
                case LIBSSH2_ERROR_CHANNEL_REQUEST_DENIED:
                case LIBSSH2_ERROR_CHANNEL_UNKNOWN:
                case LIBSSH2_ERROR_CHANNEL_WINDOW_EXCEEDED:
                case LIBSSH2_ERROR_CHANNEL_PACKET_EXCEEDED:
                case LIBSSH2_ERROR_CHANNEL_CLOSED:
                case LIBSSH2_ERROR_CHANNEL_EOF_SENT:
                    //            case LIBSSH2_ERROR_SCP_PROTOCOL:
                    //            case LIBSSH2_ERROR_ZLIB:
                case LIBSSH2_ERROR_SOCKET_TIMEOUT:
                    //            case LIBSSH2_ERROR_SFTP_PROTOCOL:
                    //            case LIBSSH2_ERROR_REQUEST_DENIED:
                    //            case LIBSSH2_ERROR_METHOD_NOT_SUPPORTED:
                    //            case LIBSSH2_ERROR_INVAL:
                    //            case LIBSSH2_ERROR_INVALID_POLL_TYPE:
                    //            case LIBSSH2_ERROR_PUBLICKEY_PROTOCOL:
                case LIBSSH2_ERROR_EAGAIN:
                    //            case LIBSSH2_ERROR_BUFFER_TOO_SMALL:
                    //            case LIBSSH2_ERROR_BAD_USE:
                    //            case LIBSSH2_ERROR_COMPRESS:
                    //            case LIBSSH2_ERROR_OUT_OF_BOUNDARY:
                case LIBSSH2_ERROR_AGENT_PROTOCOL:
                case LIBSSH2_ERROR_SOCKET_RECV:
                    //            case LIBSSH2_ERROR_ENCRYPT:
                case LIBSSH2_ERROR_BAD_SOCKET:
                case LIBSSH2_ERROR_KNOWN_HOSTS:
                    return YES;
            }
        }
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
