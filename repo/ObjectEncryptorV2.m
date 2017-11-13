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



#import <CommonCrypto/CommonDigest.h>
#import <CommonCrypto/CommonHMAC.h>
#import <CommonCrypto/CommonCryptor.h>
#import <CommonCrypto/CommonKeyDerivation.h>
#import "EncryptionDatFile.h"
#import "ObjectEncryptorV2.h"
#import "ObjectEncryptor.h"
#import "Target.h"
#import "SHA1Hash.h"
#import "NSString_extra.h"


#define HEADER "ARQO"
#define HEADER_LEN (4)
#define IV_LEN kCCBlockSizeAES128
#define SYMMETRIC_KEY_LEN kCCKeySizeAES256
#define DATA_IV_AND_SYMMETRIC_KEY_LEN (IV_LEN + SYMMETRIC_KEY_LEN)
#define ENCRYPTED_DATA_IV_AND_SYMMETRIC_KEY_LEN (DATA_IV_AND_SYMMETRIC_KEY_LEN + kCCBlockSizeAES128)
#define MAX_ENCRYPTIONS_PER_SYMMETRIC_KEY (256)
#define V3_MASTER_KEYS_LEN (kCCKeySizeAES256 * 3)
#define V2_MASTER_KEYS_LEN (kCCKeySizeAES256 * 2)


@implementation ObjectEncryptorV2
- (id)initWithTarget:(Target *)theTarget
        computerUUID:(NSString *)theComputerUUID
   encryptionDatFile:(EncryptionDatFile *)theEDF
  encryptionPassword:(NSString *)theEncryptionPassword
               error:(NSError **)error {
    if (self = [super init]) {
        target = [theTarget retain];
        computerUUID = [theComputerUUID retain];
        
        symmetricKey = (unsigned char *)malloc(SYMMETRIC_KEY_LEN);
        
        masterKeys = [[theEDF masterKeys] retain];
        masterKey = [masterKeys bytes];
        hmacKey = (unsigned char *)masterKey + kCCKeySizeAES256;
        
        encryptionVersion = [theEDF encryptionVersion];
        
        if ([theEDF encryptionVersion] == 3) {
            if ([masterKeys length] != V3_MASTER_KEYS_LEN) {
                SETNSERROR([ObjectEncryptor errorDomain], -1, @"master keys data is not %d bytes", V3_MASTER_KEYS_LEN);
                [self release];
                return nil;
            }
            blobKeySaltData = [[NSData alloc] initWithBytes:(hmacKey + kCCKeySizeAES256) length:kCCKeySizeAES256];
        } else if ([theEDF encryptionVersion] == 2) {
            if ([masterKeys length] != V2_MASTER_KEYS_LEN) {
                SETNSERROR([ObjectEncryptor errorDomain], -1, @"master keys data is not %d bytes", V2_MASTER_KEYS_LEN);
                [self release];
                return nil;
            }
            blobKeySaltData = [[computerUUID dataUsingEncoding:NSUTF8StringEncoding] retain];
        } else {
            SETNSERROR([ObjectEncryptor errorDomain], -1, @"unexpected encryption version: %d", [theEDF encryptionVersion]);
            [self release];
            return nil;
        }

        [self resetSymmetricKey];
        symmetricKeyLock = [[NSLock alloc] init];
        [symmetricKeyLock setName:@"symmetric key lock"];
    }
    return self;
}

- (void)dealloc {
    [target release];
    [computerUUID release];
    [blobKeySaltData release];
    [masterKeys release];
    free(symmetricKey);
    [symmetricKeyLock release];
    [super dealloc];
}


#pragma ObjectEncryptorImpl
- (BOOL)ensureDatFileExistsAtTargetWithEncryptionPassword:(NSString *)theEncryptionPassword targetConnectionDelegate:(id<TargetConnectionDelegate>)theTCD error:(NSError **)error {
    NSError *myError = nil;
    EncryptionDatFile *encryptionDatFile = [[[EncryptionDatFile alloc] initFromTargetWithEncryptionPassword:theEncryptionPassword target:target computerUUID:computerUUID encryptionVersion:encryptionVersion targetConnectionDelegate:theTCD error:&myError] autorelease];
    if (encryptionDatFile == nil) {
        if ([myError code] != ERROR_NOT_FOUND) {
            SETERRORFROMMYERROR;
            return NO;
        }
        
        encryptionDatFile = [[[EncryptionDatFile alloc] initFromLocalCacheWithEncryptionPassword:theEncryptionPassword target:target computerUUID:computerUUID encryptionVersion:encryptionVersion error:error] autorelease];
        if (encryptionDatFile == nil) {
            SETERRORFROMMYERROR;
            return NO;
        }
        
        // Copy the encryptionv2.dat file from cache to the destination.
        if (![encryptionDatFile saveToTargetWithTargetConnectionDelegate:theTCD error:error]) {
            return NO;
        }
    }

    return YES;
}
- (NSData *)encryptV1Data:(NSData *)theData error:(NSError **)error {
    SETNSERROR(@"ObjectEncryptorV2ErrorDomain", -1, @"encryptV1Data not supported");
    return nil;
}
- (NSString *)sha1HashForV2Data:(NSData *)theData {
    // Calculate SHA1 hash of computerUUID+plaintext.
    // Adding the computerUUID reduces data leakage and helps thwart SHA1 lookup tables.
    unsigned char digest[CC_SHA1_DIGEST_LENGTH];
    CC_SHA1_CTX ctx;
    CC_SHA1_Init(&ctx);
    CC_SHA1_Update(&ctx, [blobKeySaltData bytes], (CC_LONG)[blobKeySaltData length]);
    CC_SHA1_Update(&ctx, [theData bytes], (CC_LONG)[theData length]);
    CC_SHA1_Final(digest, &ctx);
    return [NSString hexStringWithBytes:digest length:CC_SHA1_DIGEST_LENGTH];
}
- (NSData *)v2EncryptedObjectFromData:(NSData *)theData masterIV:(NSData *)theMasterIV dataIVAndSymmetricKey:(NSData *)theDataIVAndSymmetricKey error:(NSError **)error {
    unsigned char dataIVAndSymmetricKey[DATA_IV_AND_SYMMETRIC_KEY_LEN];
    unsigned char mySymmetricKey[SYMMETRIC_KEY_LEN];

    if (theDataIVAndSymmetricKey != nil) {
        if ([theDataIVAndSymmetricKey length] < DATA_IV_AND_SYMMETRIC_KEY_LEN) {
            SETNSERROR([ObjectEncryptor errorDomain], -1, @"given dataIVAndSymmetricKey is less than %d bytes", DATA_IV_AND_SYMMETRIC_KEY_LEN);
            return nil;
        }
        memcpy(dataIVAndSymmetricKey, [theDataIVAndSymmetricKey bytes], DATA_IV_AND_SYMMETRIC_KEY_LEN);
        memcpy(mySymmetricKey, [theDataIVAndSymmetricKey bytes] + IV_LEN, SYMMETRIC_KEY_LEN);
    } else {
        // Create data IV and write it to metadata buffer.
        for (int i = 0; i < IV_LEN; i++) {
            dataIVAndSymmetricKey[i] = (unsigned char)arc4random_uniform(256);
        }
        
        // Copy symmetric key to an ivar so other threads don't change it while we're using it.
        [symmetricKeyLock lock];
        memcpy(mySymmetricKey, symmetricKey, SYMMETRIC_KEY_LEN);
        encryptCount++;
        if (encryptCount > MAX_ENCRYPTIONS_PER_SYMMETRIC_KEY) {
            [self resetSymmetricKey];
            encryptCount = 0;
        }
        [symmetricKeyLock unlock];
        
        // Copy symmetric key to metadata buffer.
        memcpy(dataIVAndSymmetricKey + IV_LEN, mySymmetricKey, SYMMETRIC_KEY_LEN);
    }
    
    // Initialize output buffer.
    NSUInteger cipherTextLen = [theData length] + kCCBlockSizeAES128;
    NSUInteger maxLen = HEADER_LEN + kCCKeySizeAES256 + IV_LEN + ENCRYPTED_DATA_IV_AND_SYMMETRIC_KEY_LEN + cipherTextLen;
    unsigned char *outbuf = (unsigned char *)malloc(maxLen);
    
    // Encrypt the plaintext with the symmetric key into theOutBuffer at offset.
    size_t numBytesEncrypted = 0;
    CCCryptorStatus status = CCCrypt(kCCEncrypt,
                                     kCCAlgorithmAES128,
                                     kCCOptionPKCS7Padding,
                                     mySymmetricKey,
                                     kCCKeySizeAES256,
                                     dataIVAndSymmetricKey,
                                     [theData bytes],
                                     [theData length],
                                     (outbuf + HEADER_LEN + CC_SHA256_DIGEST_LENGTH + IV_LEN + ENCRYPTED_DATA_IV_AND_SYMMETRIC_KEY_LEN),
                                     cipherTextLen,
                                     &numBytesEncrypted);
    if (status != kCCSuccess) {
        SETNSERROR([ObjectEncryptor errorDomain], -1, @"encrypt: %@", [self errorMessageForStatus:status]);
        free(outbuf);
        return nil;
    }
    
    // Reset theOutBuffer's length.
    NSUInteger outbuflen = HEADER_LEN + kCCKeySizeAES256 + IV_LEN + ENCRYPTED_DATA_IV_AND_SYMMETRIC_KEY_LEN + numBytesEncrypted;
    unsigned char masterIV[IV_LEN];
    if (theMasterIV != nil) {
        // Use passed-in master IV.
        if ([theMasterIV length] != IV_LEN) {
            SETNSERROR([ObjectEncryptor errorDomain], -1, @"invalid masterIV length");
            free(outbuf);
            return nil;
        }
        memcpy(masterIV, [theMasterIV bytes], IV_LEN);
    } else {
        // Create random master IV.
        for (int i = 0; i < IV_LEN; i++) {
            masterIV[i] = (unsigned char)arc4random_uniform(256);
        }
    }
    
    // Encrypt metadata buffer using first half of master key and master IV.
    unsigned char encryptedMetadata[ENCRYPTED_DATA_IV_AND_SYMMETRIC_KEY_LEN];
    memset(encryptedMetadata, 0, ENCRYPTED_DATA_IV_AND_SYMMETRIC_KEY_LEN);
    size_t encryptedMetadataActualLen = 0;
    status = CCCrypt(kCCEncrypt,
                     kCCAlgorithmAES128,
                     kCCOptionPKCS7Padding,
                     [masterKeys bytes],
                     kCCKeySizeAES256,
                     masterIV,
                     dataIVAndSymmetricKey,
                     DATA_IV_AND_SYMMETRIC_KEY_LEN,
                     encryptedMetadata,
                     ENCRYPTED_DATA_IV_AND_SYMMETRIC_KEY_LEN,
                     &encryptedMetadataActualLen);
    if (status != kCCSuccess) {
        SETNSERROR([ObjectEncryptor errorDomain], -1, @"encrypt: %@", [self errorMessageForStatus:status]);
        free(outbuf);
        return nil;
    }
    if (encryptedMetadataActualLen != ENCRYPTED_DATA_IV_AND_SYMMETRIC_KEY_LEN) {
        SETNSERROR([ObjectEncryptor errorDomain], -1, @"unexpected encrypted metadata length");
        free(outbuf);
        return nil;
    }
    
    // Calculate HMACSHA256 of (master IV + encryptedMetadata + ciphertext) using second half of master key.
    unsigned char hmacSHA256[CC_SHA256_DIGEST_LENGTH];
    CCHmacContext hmacContext;
    CCHmacInit(&hmacContext, kCCHmacAlgSHA256, hmacKey, kCCKeySizeAES256);
    CCHmacUpdate(&hmacContext, masterIV, IV_LEN);
    CCHmacUpdate(&hmacContext, encryptedMetadata, ENCRYPTED_DATA_IV_AND_SYMMETRIC_KEY_LEN);
    CCHmacUpdate(&hmacContext, (outbuf + HEADER_LEN + CC_SHA256_DIGEST_LENGTH + IV_LEN + ENCRYPTED_DATA_IV_AND_SYMMETRIC_KEY_LEN), numBytesEncrypted);
    CCHmacFinal(&hmacContext, hmacSHA256);
    
    // Copy header to outbuf.
    memcpy(outbuf, HEADER, HEADER_LEN);
    
    // Copy HMACSHA256 to outbuf.
    memcpy(outbuf + HEADER_LEN, hmacSHA256, CC_SHA256_DIGEST_LENGTH);

    // Copy master IV to outbuf.
    memcpy(outbuf + HEADER_LEN + CC_SHA256_DIGEST_LENGTH, masterIV, IV_LEN);
    
    // Copy encrypted metadata to outbuf.
    memcpy(outbuf + HEADER_LEN + CC_SHA256_DIGEST_LENGTH + IV_LEN, encryptedMetadata, ENCRYPTED_DATA_IV_AND_SYMMETRIC_KEY_LEN);
    
    return [NSData dataWithBytesNoCopy:outbuf length:outbuflen freeWhenDone:YES];
}

- (NSData *)decryptedDataForObject:(NSData *)theObject error:(NSError **)error {
    if ([theObject length] < (HEADER_LEN + CC_SHA256_DIGEST_LENGTH + IV_LEN + ENCRYPTED_DATA_IV_AND_SYMMETRIC_KEY_LEN + 1)) {
        SETNSERROR([ObjectEncryptor errorDomain], -1, @"encrypted object is too small");
        return nil;
    }
    unsigned char *bytes = (unsigned char *)[theObject bytes];
    
    // Check header.
    if (strncmp((const char *)bytes, HEADER, HEADER_LEN)) {
        SETNSERROR([ObjectEncryptor errorDomain], -1, @"object header not equal to 'ARQO'");
        return nil;
    }

    // Calculate HMACSHA256 of (master IV + encryptedMetadata + ciphertext) using second half of master key.
    unsigned char hmacSHA256[CC_SHA256_DIGEST_LENGTH];
    CCHmacContext hmacContext;
    CCHmacInit(&hmacContext, kCCHmacAlgSHA256, hmacKey, kCCKeySizeAES256);
    CCHmacUpdate(&hmacContext, bytes + HEADER_LEN + CC_SHA256_DIGEST_LENGTH, [theObject length] - HEADER_LEN - CC_SHA256_DIGEST_LENGTH);
    CCHmacFinal(&hmacContext, hmacSHA256);

    if (memcmp(hmacSHA256, bytes + HEADER_LEN, CC_SHA256_DIGEST_LENGTH)) {
        SETNSERROR([ObjectEncryptor errorDomain], -1, @"HMACSHA256 does not match");
        return nil;
    }
    
    // Create metadata buffer.
    unsigned char dataIVAndSymmetricKey[DATA_IV_AND_SYMMETRIC_KEY_LEN + kCCBlockSizeAES128];

    // Decrypt metadata into metadata buffer.
    size_t metadataBufferDecryptedLen = 0;
    CCCryptorStatus status = CCCrypt(kCCDecrypt,
                                     kCCAlgorithmAES128,
                                     kCCOptionPKCS7Padding,
                                     masterKey,
                                     kCCKeySizeAES256,
                                     (bytes + HEADER_LEN + CC_SHA256_DIGEST_LENGTH),
                                     (bytes + HEADER_LEN + CC_SHA256_DIGEST_LENGTH + IV_LEN),
                                     ENCRYPTED_DATA_IV_AND_SYMMETRIC_KEY_LEN,
                                     dataIVAndSymmetricKey,
                                     DATA_IV_AND_SYMMETRIC_KEY_LEN + kCCBlockSizeAES128,
                                     &metadataBufferDecryptedLen);
    if (status != kCCSuccess) {
        SETNSERROR([ObjectEncryptor errorDomain], -1, @"failed to decrypt session key: %@", [self errorMessageForStatus:status]);
        return nil;
    }
    if (metadataBufferDecryptedLen != DATA_IV_AND_SYMMETRIC_KEY_LEN) {
        SETNSERROR([ObjectEncryptor errorDomain], -1, @"unexpected length for decrypted iv and key: %ld", metadataBufferDecryptedLen);
        return nil;
    }
    
    unsigned char *dataIV = dataIVAndSymmetricKey;
    unsigned char *mySymmetricKey = dataIVAndSymmetricKey + IV_LEN;
    
    // Decrypt the ciphertext.
    size_t preambleLen = HEADER_LEN + CC_SHA256_DIGEST_LENGTH + IV_LEN + ENCRYPTED_DATA_IV_AND_SYMMETRIC_KEY_LEN;
    unsigned char *ciphertext = bytes + preambleLen;
    size_t ciphertextLen = [theObject length] - preambleLen;
    size_t bufsize = ciphertextLen + kCCBlockSizeAES128;
    void *buf = malloc(bufsize);
    size_t numBytesDecrypted = 0;
    status = CCCrypt(kCCDecrypt,
                     kCCAlgorithmAES128,
                     kCCOptionPKCS7Padding,
                     mySymmetricKey,
                     kCCKeySizeAES256,
                     dataIV,
                     ciphertext,
                     ciphertextLen,
                     buf,
                     bufsize,
                     &numBytesDecrypted);
    if (status != kCCSuccess) {
        free(buf);
        SETNSERROR([ObjectEncryptor errorDomain], -1, @"failed to decrypt object data: %@", [self errorMessageForStatus:status]);
        return nil;
    }
    
    NSData *ret = [NSData dataWithBytes:buf length:numBytesDecrypted];
    free(buf);
    return ret;
}
- (NSData *)decryptedDataForObject:(NSData *)theObject blobKey:(BlobKey *)theBlobKey error:(NSError **)error {
    return [self decryptedDataForObject:theObject error:error];
}

- (BOOL)masterIV:(NSData **)theMasterIV dataIVAndSymmetricKey:(NSData **)theDataIVAndSymmetricKey fromEncryptedObjectHeader:(NSData *)theHeader error:(NSError **)error {
    if ([theHeader length] < (HEADER_LEN + CC_SHA256_DIGEST_LENGTH + IV_LEN + ENCRYPTED_DATA_IV_AND_SYMMETRIC_KEY_LEN)) {
        SETNSERROR([ObjectEncryptor errorDomain], -1, @"encrypted object header is too small");
        return NO;
    }

    // Create metadata buffer.
    unsigned char dataIVAndSymmetricKey[DATA_IV_AND_SYMMETRIC_KEY_LEN + kCCBlockSizeAES128];
    
    // Decrypt metadata into metadata buffer.
    size_t metadataBufferDecryptedLen = 0;
    CCCryptorStatus status = CCCrypt(kCCDecrypt,
                                     kCCAlgorithmAES128,
                                     kCCOptionPKCS7Padding,
                                     masterKey,
                                     kCCKeySizeAES256,
                                     ([theHeader bytes] + HEADER_LEN + CC_SHA256_DIGEST_LENGTH),
                                     ([theHeader bytes] + HEADER_LEN + CC_SHA256_DIGEST_LENGTH + IV_LEN),
                                     ENCRYPTED_DATA_IV_AND_SYMMETRIC_KEY_LEN,
                                     dataIVAndSymmetricKey,
                                     DATA_IV_AND_SYMMETRIC_KEY_LEN + kCCBlockSizeAES128,
                                     &metadataBufferDecryptedLen);
    if (status != kCCSuccess) {
        SETNSERROR([ObjectEncryptor errorDomain], -1, @"failed to decrypt session key: %@", [self errorMessageForStatus:status]);
        return NO;
    }
    if (metadataBufferDecryptedLen != DATA_IV_AND_SYMMETRIC_KEY_LEN) {
        SETNSERROR([ObjectEncryptor errorDomain], -1, @"unexpected length for decrypted iv and key: %ld", metadataBufferDecryptedLen);
        return NO;
    }

    if (theMasterIV != NULL) {
        *theMasterIV = [NSData dataWithBytes:([theHeader bytes] + HEADER_LEN + CC_SHA256_DIGEST_LENGTH) length:IV_LEN];
    }
    if (theDataIVAndSymmetricKey != NULL) {
        *theDataIVAndSymmetricKey = [NSData dataWithBytes:dataIVAndSymmetricKey length:metadataBufferDecryptedLen];
    }
    return YES;
}


#pragma mark internal
- (void)resetSymmetricKey {
    // Create 32-byte random symmetric key.
    for (int i = 0; i < SYMMETRIC_KEY_LEN; i++) {
        symmetricKey[i] = (unsigned char)arc4random_uniform(256);
    }
}
- (NSString *)errorMessageForStatus:(CCCryptorStatus)status {
    if (status == kCCBufferTooSmall) {
        return @"buffer too small";
    }
    if (status == kCCAlignmentError) {
        return @"alignment error";
    }
    if (status == kCCDecodeError) {
        return @"decode error";
    }
    return [NSString stringWithFormat:@"CCCryptorStatus error %d", status];
}
@end
