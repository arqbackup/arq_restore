//
//  OpenSSL.h
//  Arq
//
//  Created by Stefan Reitshamer on 10/8/12.
//  Copyright (c) 2012 Stefan Reitshamer. All rights reserved.
//

#import <openssl/ssl.h>

@interface OpenSSL : NSObject {
    
}
+ (BOOL)initializeSSL:(NSError **)error;
+ (SSL_CTX *)context;
+ (NSString *)errorMessage;

@end
