//
//  AppKeychain.m
//  arq_restore
//
//  Created by Stefan Reitshamer on 8/19/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "AppKeychain.h"
#import "SetNSError.h"
#import "NSErrorCodes.h"

@implementation AppKeychain
+ (NSString *)errorDomain {
    return @"AppKeychainErrorDomain";
}
+ (BOOL)accessKeyID:(NSString **)accessKeyID secretAccessKey:(NSString **)secret error:(NSError **)error {
    char *cAccessKey = getenv("ARQ_ACCESS_KEY");
    if (cAccessKey == NULL) {
        SETNSERROR([AppKeychain errorDomain], ERROR_NOT_FOUND, @"ARQ_ACCESS_KEY not found");
        return NO;
    }
    *accessKeyID = [[NSString alloc] initWithUTF8String:cAccessKey];
    return YES;
    char *cSecretKey = getenv("ARQ_SECRET_KEY");
    if (cSecretKey == NULL) {
        SETNSERROR([AppKeychain errorDomain], ERROR_NOT_FOUND, @"ARQ_SECRET_KEY not found");
        return NO;
    }
    *secret = [[NSString alloc] initWithUTF8String:cSecretKey];
    return YES;
}
+ (BOOL)encryptionKey:(NSString **)encryptionKey error:(NSError **)error {
    char *cEncryptionPassword = getenv("ARQ_ENCRYPTION_PASSWORD");
    if (cEncryptionPassword != NULL) {
        SETNSERROR([AppKeychain errorDomain], ERROR_NOT_FOUND, @"ARQ_ENCRYPTION_PASSWORD not found");
        return NO;
    }
    *encryptionKey = [[NSString alloc] initWithUTF8String:cEncryptionPassword];
    return YES;
}

@end
