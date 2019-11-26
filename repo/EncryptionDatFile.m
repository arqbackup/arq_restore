/*
 Copyright (c) 2009-2017, Haystack Software LLC https://www.arqbackup.com
 
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



#import <CommonCrypto/CommonHMAC.h>
#import <CommonCrypto/CommonKeyDerivation.h>
#import <CommonCrypto/CommonDigest.h>
#import <CommonCrypto/CommonCryptor.h>
#import "EncryptionDatFile.h"
#import "Target.h"
#import "UserLibrary_Arq.h"
#import "StringIO.h"
#import "BufferedInputStream.h"
#import "DataInputStream.h"
#import "TargetConnection.h"
#import "NSFileManager_extra.h"
#import "NSData-Random.h"
#import "CacheOwnership.h"
#import "Streams.h"


#define SALT_LENGTH (8)
#define IV_LENGTH (16)
#define KEY_DERIVATION_ROUNDS (200000)
#define HEADER "ENCRYPTIONV2"



@implementation EncryptionDatFile
+ (NSString *)errorDomain {
    return @"EncryptionDatFileErrorDomain";
}

+ (EncryptionDatFile *)encryptionDatFileForTarget:(Target *)theTarget
                                     computerUUID:(NSString *)theComputerUUID
                               encryptionPassword:(NSString *)theEncryptionPassword
                         targetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD
                                            error:(NSError **)error {
    NSError *myError = nil;
    
    // Try to read local v3 file.
    EncryptionDatFile *datFile = [[[EncryptionDatFile alloc] initFromLocalCacheWithEncryptionPassword:theEncryptionPassword
                                                                                               target:theTarget
                                                                                         computerUUID:theComputerUUID
                                                                                    encryptionVersion:3
                                                                                                error:&myError] autorelease];
    if (datFile == nil) {
        if ([myError code] != ERROR_NOT_FOUND) {
            SETERRORFROMMYERROR;
            return nil;
        }
        // Try to read local v2 file.
        datFile = [[[EncryptionDatFile alloc] initFromLocalCacheWithEncryptionPassword:theEncryptionPassword
                                                                                target:theTarget
                                                                          computerUUID:theComputerUUID
                                                                     encryptionVersion:2
                                                                                 error:&myError] autorelease];
    }
    if (datFile == nil) {
        if ([myError code] != ERROR_NOT_FOUND) {
            SETERRORFROMMYERROR;
            return nil;
        }
        // Try to read local v1 file.
        datFile = [[[EncryptionDatFile alloc] initFromLocalCacheWithEncryptionPassword:theEncryptionPassword
                                                                                target:theTarget
                                                                          computerUUID:theComputerUUID
                                                                     encryptionVersion:1
                                                                                 error:&myError] autorelease];
    }
    if (datFile == nil) {
        if ([myError code] != ERROR_NOT_FOUND) {
            SETERRORFROMMYERROR;
            return nil;
        }
        // Try to read v3 file from target.
        datFile = [[[EncryptionDatFile alloc] initFromTargetWithEncryptionPassword:theEncryptionPassword
                                                                            target:theTarget
                                                                      computerUUID:theComputerUUID
                                                                 encryptionVersion:3
                                                          targetConnectionDelegate:theTCD
                                                                             error:&myError] autorelease];
        if (datFile != nil) {
            NSError *cacheError = nil;
            if (![datFile saveToLocalCache:&cacheError]) {
                HSLogError(@"failed to save encryption dat file to local cache: %@", cacheError);
            }
        }
    }
    if (datFile == nil) {
        if ([myError code] != ERROR_NOT_FOUND) {
            SETERRORFROMMYERROR;
            return nil;
        }
        // Try to read v2 file from target.
        datFile = [[[EncryptionDatFile alloc] initFromTargetWithEncryptionPassword:theEncryptionPassword
                                                                            target:theTarget
                                                                      computerUUID:theComputerUUID
                                                                 encryptionVersion:2
                                                          targetConnectionDelegate:theTCD
                                                                             error:&myError] autorelease];
        if (datFile != nil) {
            NSError *cacheError = nil;
            if (![datFile saveToLocalCache:&cacheError]) {
                HSLogError(@"failed to save encryption dat file to local cache: %@", cacheError);
            }
        }
    }
    if (datFile == nil) {
        if ([myError code] != ERROR_NOT_FOUND) {
            SETERRORFROMMYERROR;
            return nil;
        }
        // Try to read v1 file from target.
        datFile = [[[EncryptionDatFile alloc] initFromTargetWithEncryptionPassword:theEncryptionPassword
                                                                            target:theTarget
                                                                      computerUUID:theComputerUUID
                                                                 encryptionVersion:1
                                                          targetConnectionDelegate:theTCD
                                                                             error:&myError] autorelease];
        if (datFile != nil) {
            NSError *cacheError = nil;
            if (![datFile saveToLocalCache:&cacheError]) {
                HSLogError(@"failed to save encryption dat file to local cache: %@", cacheError);
            }
        }
    }
    if (datFile == nil) {
        if ([myError code] != ERROR_NOT_FOUND) {
            SETERRORFROMMYERROR;
            return nil;
        }
    }
    if (datFile == nil) {
        SETNSERROR([EncryptionDatFile errorDomain], ERROR_NOT_FOUND, @"no encryption dat file found for target %@ computerUUID %@", theTarget, theComputerUUID);
    }
    return datFile;
}

- (id)initFromLocalCacheWithEncryptionPassword:(NSString *)theEncryptionPassword
                                        target:(Target *)theTarget
                                  computerUUID:(NSString *)theComputerUUID
                             encryptionVersion:(int)theEncryptionVersion
                                         error:(NSError **)error {
    if (self = [super init]) {
        encryptionPassword = [theEncryptionPassword retain];
        target = [theTarget retain];
        computerUUID = [theComputerUUID retain];
        encryptionVersion = theEncryptionVersion;
        
        if (![self loadFromLocalCache:error]) {
            [self release];
            return nil;
        }
    }
    return self;
}
- (id)initFromTargetWithEncryptionPassword:(NSString *)theEncryptionPassword
                                    target:(Target *)theTarget
                              computerUUID:(NSString *)theComputerUUID
                         encryptionVersion:(int)theEncryptionVersion
                  targetConnectionDelegate:(id<TargetConnectionDelegate>)theTCD
                                     error:(NSError **)error {
    if (self = [super init]) {
        encryptionPassword = [theEncryptionPassword retain];
        target = [theTarget retain];
        computerUUID = [theComputerUUID retain];
        encryptionVersion = theEncryptionVersion;
        
        if (![self loadFromTargetWithTargetConnectionDelegate:theTCD error:error]) {
            [self release];
            return nil;
        }
    }
    return self;
}
- (void)dealloc {
    [encryptionPassword release];
    [target release];
    [computerUUID release];
    [data release];
    [masterKeys release];
    [super dealloc];
}

- (NSString *)errorDomain {
    return @"EncryptionDatFileErrorDomain";
}

- (int)encryptionVersion {
    return encryptionVersion;
}
- (BOOL)saveToTargetWithTargetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD error:(NSError **)error {
    TargetConnection *conn = [[target newConnection:error] autorelease];
    if (conn == nil) {
        return NO;
    }
    return [conn setEncryptionData:data forComputerUUID:computerUUID encryptionVersion:encryptionVersion delegate:theTCD error:error];
}
- (BOOL)deleteLocalCache:(NSError **)error {
    NSString *cachePath = [self cachePath];
    if ([[NSFileManager defaultManager] fileExistsAtPath:cachePath]) {
        if (![[NSFileManager defaultManager] removeItemAtPath:cachePath error:error]) {
            return NO;
        }
    }
    return YES;
}
- (BOOL)saveToLocalCache:(NSError **)error {
    NSString *cachePath = [self cachePath];
    if (![[NSFileManager defaultManager] ensureParentPathExistsForPath:cachePath targetUID:[[CacheOwnership sharedCacheOwnership] uid] targetGID:[[CacheOwnership sharedCacheOwnership] gid] error:error]) {
        return NO;
    }
    if (![Streams writeData:data atomicallyToFile:cachePath targetUID:[[CacheOwnership sharedCacheOwnership] uid] targetGID:[[CacheOwnership sharedCacheOwnership] gid] bytesWritten:NULL error:error]) {
        return NO;
    }
    HSLogDetail(@"wrote encryption dat file to %@", cachePath);
    return YES;
}
- (NSData *)masterKeys {
    return masterKeys;
}


#pragma mark internal
- (BOOL)loadFromLocalCache:(NSError **)error {
    NSString *cachePath = [self cachePath];
    if (![[NSFileManager defaultManager] fileExistsAtPath:cachePath]) {
        SETNSERROR([self errorDomain], ERROR_NOT_FOUND, @"encryption dat file cache not found");
        return NO;
    }
    data = [[NSData dataWithContentsOfFile:cachePath options:NSUncachedRead error:error] retain];
    if (data == nil) {
        return NO;
    }
    return [self loadPrivateKeyFromData:error];
}
- (BOOL)loadFromTargetWithTargetConnectionDelegate:(id<TargetConnectionDelegate>)theTCD error:(NSError **)error {
    TargetConnection *conn = [target newConnection:error];
    if (conn == nil) {
        return NO;
    }
    data = [[conn encryptionDataForComputerUUID:computerUUID encryptionVersion:encryptionVersion delegate:theTCD error:error] retain];
    [conn release];
    if (data == nil) {
        return NO;
    }
    return [self loadPrivateKeyFromData:error];
}


#pragma mark internal
- (id)initWithEncryptionPassword:(NSString *)theEncryptionPassword
                          target:(Target *)theTarget
                    computerUUID:(NSString *)theComputerUUID
               encryptionVersion:(int)theEncryptionVersion
                            data:(NSData *)theData
                       masterKeys:(NSData *)theMasterKeys {
    if (self = [super init]) {
        encryptionPassword = [theEncryptionPassword retain];
        target = [theTarget retain];
        computerUUID = [theComputerUUID retain];
        encryptionVersion = theEncryptionVersion;
        data = [theData retain];
        masterKeys = [theMasterKeys retain];
    }
    return self;
}

- (BOOL)loadPrivateKeyFromData:(NSError **)error {
    if ([data length] < (strlen(HEADER) + SALT_LENGTH + CC_SHA256_DIGEST_LENGTH + IV_LENGTH + 1)) {
        SETNSERROR([self errorDomain], -1, @"not enough bytes in dat file");
        return NO;
    }
    const unsigned char *bytes = (const unsigned char *)[data bytes];
    
    if (strncmp((const char *)bytes, HEADER, strlen(HEADER))) {
        SETNSERROR([self errorDomain], -1, @"invalid header");
        return NO;
    }
    
    // Derive 64-byte encryption key from theEncryptionPassword.
    NSData *thePasswordData = [encryptionPassword dataUsingEncoding:NSUTF8StringEncoding];
    void *derivedEncryptionKey = malloc(kCCKeySizeAES256 * 2);
    const unsigned char *salt = bytes + strlen(HEADER);
    CCKeyDerivationPBKDF(kCCPBKDF2, [thePasswordData bytes], [thePasswordData length], salt, SALT_LENGTH, kCCPRFHmacAlgSHA1, KEY_DERIVATION_ROUNDS, derivedEncryptionKey, kCCKeySizeAES256 * 2);
    void *derivedHMACKey = derivedEncryptionKey + kCCKeySizeAES256;
    
    // Calculate HMACSHA256 of IV + encrypted master keys, using derivedHMACKey.
    unsigned char hmacSHA256[CC_SHA256_DIGEST_LENGTH];
    CCHmacContext hmacContext;
    CCHmacInit(&hmacContext, kCCHmacAlgSHA256, derivedHMACKey, kCCKeySizeAES256);
    const unsigned char *iv = bytes + strlen(HEADER) + SALT_LENGTH + CC_SHA256_DIGEST_LENGTH;
    CCHmacUpdate(&hmacContext, bytes + strlen(HEADER) + SALT_LENGTH + CC_SHA256_DIGEST_LENGTH, [data length] - strlen(HEADER) - SALT_LENGTH - CC_SHA256_DIGEST_LENGTH);
    CCHmacFinal(&hmacContext, hmacSHA256);
    
    if (memcmp(hmacSHA256, bytes + strlen(HEADER) + SALT_LENGTH, CC_SHA256_DIGEST_LENGTH)) {
        free(derivedEncryptionKey);
        SETNSERROR([self errorDomain], -1, @"HMACSHA256 does not match");
        return NO;
    }
    
    // Decrypt master keys.
    NSUInteger expectedKeysLen = (encryptionVersion == 3) ? (kCCKeySizeAES256 * 3) : (kCCKeySizeAES256 * 2);
    size_t theMasterKeysLen = expectedKeysLen + kCCBlockSizeAES128;
    NSMutableData *theMasterKeys = [NSMutableData dataWithLength:theMasterKeysLen];
    size_t theMasterKeysActualLen = 0;
    const unsigned char *encryptedMasterKeys = bytes + strlen(HEADER) + SALT_LENGTH + CC_SHA256_DIGEST_LENGTH + IV_LENGTH;
    size_t encryptedMasterKeysLen = [data length] - strlen(HEADER) - SALT_LENGTH - CC_SHA256_DIGEST_LENGTH - IV_LENGTH;
    CCCryptorStatus status = CCCrypt(kCCDecrypt,
                                     kCCAlgorithmAES128,
                                     kCCOptionPKCS7Padding,
                                     derivedEncryptionKey,
                                     kCCKeySizeAES256,
                                     iv,
                                     encryptedMasterKeys,
                                     encryptedMasterKeysLen,
                                     [theMasterKeys mutableBytes],
                                     theMasterKeysLen,
                                     &theMasterKeysActualLen);
    if (status != kCCSuccess) {
        free(derivedEncryptionKey);
        SETNSERROR([self errorDomain], -1, @"decrypt failed");
        return NO;
    }
    [theMasterKeys setLength:theMasterKeysActualLen];
    
    free(derivedEncryptionKey);

    [masterKeys release];
    masterKeys = [theMasterKeys copy];
    
    if ([masterKeys length] != expectedKeysLen && encryptionVersion != 1) {
        SETNSERROR([EncryptionDatFile errorDomain], -1, @"unexpected master keys length %ld (expected %ld)", [masterKeys length], expectedKeysLen);
        return NO;
    }
    
    return YES;
}

- (NSString *)cachePath {
    return [NSString stringWithFormat:@"%@/%@/%@/encryptionv%d.dat", [UserLibrary arqCachePath], [target targetUUID], computerUUID, encryptionVersion];
}
@end
