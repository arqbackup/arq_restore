/*
 Copyright (c) 2009, Stefan Reitshamer http://www.haystacksoftware.com
 
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

#include "dns_sd.h"
#import "DNS_SDErrors.h"


@implementation DNS_SDErrors
+ (NSString *)descriptionForDNS_SDError:(int)code {
    switch(code) {
        case kDNSServiceErr_NoError:
            return @"DNS service no error";
        case kDNSServiceErr_Unknown:
            return @"DNS service unknown error";
        case kDNSServiceErr_NoSuchName:
            return @"DNS service: no such name";
        case kDNSServiceErr_NoMemory:
            return @"DNS service: no memory";
        case kDNSServiceErr_BadParam:
            return @"DNS service: bad parameter";
        case kDNSServiceErr_BadReference:
            return @"DNS service: bad reference";
        case kDNSServiceErr_BadState:
            return @"DNS service: bad state";
        case kDNSServiceErr_BadFlags:
            return @"DNS service: bad flags";
        case kDNSServiceErr_Unsupported:
            return @"DNS service: unsupported";
        case kDNSServiceErr_NotInitialized:
            return @"DNS service: not initialized";
        case kDNSServiceErr_AlreadyRegistered:
            return @"DNS service: already registered";
        case kDNSServiceErr_NameConflict:
            return @"DNS service: name conflict";
        case kDNSServiceErr_Invalid:
            return @"DNS service: invalid";
        case kDNSServiceErr_Firewall:
            return @"DNS service: firewall error";
        case kDNSServiceErr_Incompatible:
            return @"DNS service: incompatible";
        case kDNSServiceErr_BadInterfaceIndex:
            return @"DNS service: bad interface index";
        case kDNSServiceErr_Refused:
            return @"DNS service: refused";
        case kDNSServiceErr_NoSuchRecord:
            return @"DNS service: no such record";
        case kDNSServiceErr_NoAuth:
            return @"DNS service: no auth";
        case kDNSServiceErr_NoSuchKey:
            return @"DNS service: no such key";
        case kDNSServiceErr_NATTraversal:
            return @"DNS service: NAT traversal error";
        case kDNSServiceErr_DoubleNAT:
            return @"DNS service: double NAT error";
        case kDNSServiceErr_BadTime:
            return @"DNS service: bad time";
        case kDNSServiceErr_BadSig:
            return @"DNS service: bad sig";
        case kDNSServiceErr_BadKey:
            return @"DNS service: bad key";
        case kDNSServiceErr_Transient:
            return @"DNS service: transient";
        case kDNSServiceErr_ServiceNotRunning:
            return @"DNS service not running";
        case kDNSServiceErr_NATPortMappingUnsupported:
            return @"DNS service: NAT port mapping unsupported";
        case kDNSServiceErr_NATPortMappingDisabled:
            return @"DNS service: NAT port mapping disabled";
    }
    return @"unknown DNS service error";
}
@end
