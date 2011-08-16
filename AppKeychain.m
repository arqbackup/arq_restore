//
//  AppKeychain.m
//  Backup
//
//  Created by Stefan Reitshamer on 8/26/09.
//  Copyright 2009 PhotoMinds LLC. All rights reserved.
//

#import "AppKeychain.h"
#import "SetNSError.h"
#import "UserLibrary.h"

#define ARQ_S3_LABEL @"Arq S3"
#define ARQ_TWITTER_LABEL @"Arq Twitter Access Token"
#define ARQ_ENCRYPTION_ACCOUNT_LABEL @"EncryptionKey"

@interface AppKeychain (internal)
+ (NSString *)encryptionPasswordLabelForS3BucketName:(NSString *)theS3BucketName computerUUID:(NSString *)theComputerUUID;
+ (BOOL)account:(NSString **)account password:(NSString **)password forLabel:(NSString *)label error:(NSError **)error;
+ (BOOL)findItem:(NSString *)theLabel item:(SecKeychainItemRef *)item error:(NSError **)error;
- (BOOL)loadSecAccess:(NSError **)error;
- (BOOL)deleteLabel:(NSString *)theLabel error:(NSError **)error;
- (BOOL)addLabel:(NSString *)theLabel account:(NSString *)theAccount password:(NSString *)thePassword error:(NSError **)error;
@end

@implementation AppKeychain
+ (BOOL)accessKeyID:(NSString **)accessKey secretAccessKey:(NSString **)secret error:(NSError **)error {
    NSString *account = nil;
    NSString *password = nil;
    if (![AppKeychain account:&account password:&password forLabel:ARQ_S3_LABEL error:error]) {
        return NO;
    }
    if (accessKey != nil) {
        *accessKey = account;
    }
    if (secret != nil) {
        *secret = password;
    }
    return YES;
}
+ (BOOL)containsEncryptionPasswordForS3BucketName:(NSString *)theS3BucketName computerUUID:(NSString *)theComputerUUID {
    NSString *encryptionPassword = nil;
    NSError *myError = nil;
    return [AppKeychain encryptionPassword:&encryptionPassword forS3BucketName:theS3BucketName computerUUID:theComputerUUID error:&myError];
}
+ (BOOL)encryptionPassword:(NSString **)encryptionPassword forS3BucketName:(NSString *)theS3BucketName computerUUID:(NSString *)theComputerUUID error:(NSError **)error {
    NSString *label = [AppKeychain encryptionPasswordLabelForS3BucketName:theS3BucketName computerUUID:theComputerUUID];
    NSString *account = nil;
    NSString *password = nil;
    if (![AppKeychain account:&account password:&password forLabel:label error:error]) {
        return NO;
    }
    if (encryptionPassword != nil) {
        *encryptionPassword = password;
    }
    return YES;
}
+ (BOOL)twitterAccessKey:(NSString **)theAccessKey secret:(NSString **)secret error:(NSError **)error {
    return [AppKeychain account:theAccessKey password:secret forLabel:ARQ_TWITTER_LABEL error:error];
}


- (id)initWithBackupAppPath:(NSString *)theBackupAppPath 
               agentAppPath:(NSString *)theAgentAppPath {
    if (self = [super init]) {
        backupAppPath = [theBackupAppPath copy];
        agentAppPath = [theAgentAppPath copy];
    }
    return self;
}
- (void)dealloc {
    if (access != NULL) {
        CFRelease(access);
    }
    [backupAppPath release];
    [agentAppPath release];
    [super dealloc];
}
- (BOOL)setAccessKeyID:(NSString *)theAccessKeyID
       secretAccessKey:(NSString *)theSecretAccessKey
                 error:(NSError **)error {
    return [self addLabel:ARQ_S3_LABEL account:theAccessKeyID password:theSecretAccessKey error:error];
}
- (BOOL)setEncryptionKey:(NSString *)theEncryptionPassword
         forS3BucketName:(NSString *)theS3BucketName
            computerUUID:(NSString *)theComputerUUID
                   error:(NSError **)error {
    NSString *label = [AppKeychain encryptionPasswordLabelForS3BucketName:theS3BucketName computerUUID:theComputerUUID];
    return [self addLabel:label account:ARQ_ENCRYPTION_ACCOUNT_LABEL password:theEncryptionPassword error:error];
}
- (BOOL)setTwitterAccessKey:(NSString *)theKey secret:(NSString *)theSecret error:(NSError **)error {
    return [self addLabel:ARQ_TWITTER_LABEL account:theKey password:theSecret error:error];
}
- (BOOL)deleteTwitterAccessKey:(NSError **)error {
    return [self deleteLabel:ARQ_TWITTER_LABEL error:error];
}
@end

@implementation AppKeychain (internal)
+ (NSString *)encryptionPasswordLabelForS3BucketName:(NSString *)theS3BucketName computerUUID:(NSString *)theComputerUUID {
    return [NSString stringWithFormat:@"Arq Encryption:%@:%@", theS3BucketName, theComputerUUID];
}
+ (BOOL)account:(NSString **)account password:(NSString **)password forLabel:(NSString *)theLabel error:(NSError **)error {
    SecKeychainItemRef item = NULL;
    if (![AppKeychain findItem:theLabel item:&item error:error]) {
        return NO;
    }
    if (item == NULL) {
        SETNSERROR(@"AppKeychainErrorDomain", -1, @"Keychain item %@ not found", theLabel);
        return NO;
    }
    SecKeychainAttributeList *outAttrList = NULL;
    UInt32 length;
    void *data;
    UInt32 tags[] = {
        kSecAccountItemAttr
    };
    UInt32 formats[] = {
        CSSM_DB_ATTRIBUTE_FORMAT_STRING
    };
    SecKeychainAttributeInfo info = {
        1,
        tags,
        formats
    };
    OSStatus oss = SecKeychainItemCopyAttributesAndData(item, &info, NULL, &outAttrList, &length, &data);
    if (oss != noErr) {
        NSString *errorMessage = (NSString *)SecCopyErrorMessageString(oss, NULL);
        SETNSERROR(@"AppKeychainErrorDomain", -1, @"Error reading data from Keychain item %@: %@ (code %d)", theLabel, errorMessage, oss);
        [errorMessage release];
        return NO;
    }
    if (account != nil) {
        *account = nil;
        for (UInt32 index = 0; index < outAttrList->count; index++) {
            SecKeychainAttribute *attr = outAttrList->attr + index;
            if (attr->tag == kSecAccountItemAttr) {
                *account = [[[NSString alloc] initWithBytes:attr->data length:attr->length encoding:NSUTF8StringEncoding] autorelease];
                break;
            }
        }
    }
    if (password != nil) {
        *password = [[[NSString alloc] initWithBytes:data length:length encoding:NSUTF8StringEncoding] autorelease];
    }
    SecKeychainItemFreeAttributesAndData(outAttrList, data);
    CFRelease(item);
    return YES;
}
+ (BOOL)findItem:(NSString *)theLabel item:(SecKeychainItemRef *)item error:(NSError **)error {
    *item = NULL;
    const char *label = [theLabel UTF8String];
    SecKeychainAttribute attrs[] = {
        {
            kSecLabelItemAttr, 
            strlen(label), 
            (char *)label
        }
    };
    SecKeychainAttributeList attributes = {
        sizeof(attrs) / sizeof(attrs[0]),
        attrs
    };
    SecKeychainSearchRef searchRef;
    OSStatus oss;
    oss = SecKeychainSearchCreateFromAttributes(NULL, kSecGenericPasswordItemClass, &attributes, &searchRef);
    if (oss != noErr) {
        SETNSERROR(@"AppKeychainErrorDomain", -1, @"error creating keychain search");
        return NO;
    }
    SecKeychainSearchCopyNext(searchRef, item);
    CFRelease(searchRef);
    return YES;
}

- (BOOL)loadSecAccess:(NSError **)error {
    if (access == NULL) {
        NSMutableArray *trustedApplications = [NSMutableArray array];
        OSStatus oss;
        SecTrustedApplicationRef agentApp;
        oss = SecTrustedApplicationCreateFromPath([agentAppPath fileSystemRepresentation], &agentApp);
        if (oss != noErr) {
            CFStringRef msg = SecCopyErrorMessageString(oss, NULL);
            SETNSERROR(@"AppKeychainErrorDomain", -1, @"Error creating Agent trusted application %@: %@ (code %d)", agentAppPath, (NSString *)msg, oss);
            CFRelease(msg);
            return NO;
        }
        [trustedApplications addObject:(id)agentApp];
        CFRelease(agentApp);
        
        SecTrustedApplicationRef backupApp;
        oss = SecTrustedApplicationCreateFromPath([backupAppPath fileSystemRepresentation], &backupApp);
        if (oss != noErr) {
            CFStringRef msg = SecCopyErrorMessageString(oss, NULL);
            SETNSERROR(@"AppKeychainErrorDomain", -1, @"Error creating trusted application: %@ (code %d)", (NSString *)msg, oss);
            CFRelease(agentApp);
            CFRelease(msg);
            return NO;
        }
        [trustedApplications addObject:(id)backupApp];
        CFRelease(backupApp);
    
        
        oss = SecAccessCreate((CFStringRef)@"Arq", (CFArrayRef)trustedApplications, &access);
        if (oss != noErr) {
            CFStringRef msg = SecCopyErrorMessageString(oss, NULL);
            SETNSERROR(@"AppKeychainErrorDomain", -1, @"Error creating SecAccessRef: %@ (code %d)", (NSString *)msg, oss);
            CFRelease(msg);
            return NO;
        }
    }
    return YES;
}
- (BOOL)deleteLabel:(NSString *)theLabel error:(NSError **)error {
    SecKeychainItemRef item = NULL;
    if (![AppKeychain findItem:theLabel item:&item error:error]) {
        return NO;
    }
    if (item != NULL) {
        OSStatus oss = SecKeychainItemDelete(item);
        CFRelease(item);
        if (oss != noErr) {
            NSString *errorMessage = (NSString *)SecCopyErrorMessageString(oss, NULL);
            SETNSERROR(@"AppKeychainErrorDomain", -1, @"error deleting item for label %@: %@ (code %d)", theLabel, errorMessage, oss);
            [errorMessage release];
            return NO;
        }
    }
    return YES;
}
- (BOOL)addLabel:(NSString *)theLabel account:(NSString *)theAccount password:(NSString *)thePassword error:(NSError **)error {
    if (![self loadSecAccess:error]) {
        return NO;
    }
    if (![self deleteLabel:theLabel error:error]) {
        return NO;
    }
    const char *label = [theLabel UTF8String];
    const char *account = [theAccount UTF8String];
    const char *password = [thePassword UTF8String];
    SecKeychainAttribute attrs[] = {
        {
            kSecLabelItemAttr, 
            strlen(label), 
            (char *)label
        },
        {
            kSecAccountItemAttr,
            strlen(account),
            (char *)account
        },
        {
            kSecServiceItemAttr,
            strlen(label),
            (char *)label
        }
    };
    SecKeychainAttributeList attributes = {
        sizeof(attrs) / sizeof(attrs[0]),
        attrs
    };
    OSStatus oss = SecKeychainItemCreateFromContent(kSecGenericPasswordItemClass, &attributes, strlen(password), password, NULL, access, NULL);
    if (oss != noErr) {
        NSString *errorMessage = (NSString *)SecCopyErrorMessageString(oss, NULL);
        SETNSERROR(@"AppKeychainErrorDomain", -1, @"Error creating keychain item: %@ (code %d)", errorMessage, oss);
        [errorMessage release];
        return NO;
    }
    return YES;
}
@end
