//
//  OpenSSL.m
//  Arq
//
//  Created by Stefan Reitshamer on 10/8/12.
//  Copyright (c) 2012 Stefan Reitshamer. All rights reserved.
//

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