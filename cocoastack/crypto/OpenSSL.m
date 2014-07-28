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

#ifdef USE_OPENSSL


#import "OpenSSL.h"
#import <openssl/err.h>
#import <openssl/ssl.h>


static BOOL initialized = NO;
static SSL_CTX *ctx;


@implementation OpenSSL
+ (BOOL)initializeSSL:(NSError **)error {
    if (!initialized) {
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
        SSL_library_init();
        OpenSSL_add_all_algorithms();
        SSL_load_error_strings();
        ERR_load_crypto_strings();
        ctx = SSL_CTX_new(SSLv23_method());
        if (ctx == NULL) {
            SETNSERROR(@"SSLErrorDomain", -1, @"SSL_CTX_new: %@",  [OpenSSL errorMessage]);
            return NO;
        }
        initialized = YES;
#pragma GCC diagnostic warning "-Wdeprecated-declarations"
    }
    return YES;
}
+ (SSL_CTX *)context {
    return ctx;
}
+ (NSString *)errorMessage {
    NSMutableString *msg = [NSMutableString string];
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
    for (;;) {
        unsigned long err = ERR_get_error();
        if (err == 0) {
            break;
        }
        if ([msg length] > 0) {
            [msg appendString:@"; "];
        }
        HSLogTrace(@"%s", ERR_error_string(err, NULL));
        [msg appendFormat:@"%s", ERR_reason_error_string(err)];
    }
    if ([msg length] == 0) {
        [msg appendString:@"(no error)"];
    }
#pragma GCC diagnostic warning "-Wdeprecated-declarations"
    return msg;
}

@end


#endif /* USE_OPENSSL */