/*
 Arq7EncryptedObjectDecryptor — port of arq7's Decryptor.m, simplified.
 ARQO format (from EncryptedBlobConstants.h):
   [4]  Header "ARQO"
   [32] HMAC-SHA256  (over: masterIV + encryptedMetadata + ciphertext)
   [16] masterIV
   [64] encrypted(dataIV[16] + sessionKey[32])  — AES-256-CBC with encryptionKey + masterIV
   [N]  ciphertext  — AES-256-CBC with sessionKey + dataIV
*/

#import <CommonCrypto/CommonHMAC.h>
#import <CommonCrypto/CommonCryptor.h>
#import <CommonCrypto/CommonDigest.h>
#import "Arq7EncryptedObjectDecryptor.h"
#import "Arq7KeySet.h"


#define ARQO_HEADER         "ARQO"
#define ARQO_HEADER_LEN     (4)
#define ARQO_IV_LEN         (16)                                    // kCCBlockSizeAES128
#define ARQO_SYMKEY_LEN     (32)                                    // kCCKeySizeAES256
#define ARQO_META_PLAIN_LEN (ARQO_IV_LEN + ARQO_SYMKEY_LEN)        // 48 bytes
#define ARQO_META_ENC_LEN   (ARQO_META_PLAIN_LEN + ARQO_IV_LEN)    // 64 bytes (48 + 16 padding block)
#define ARQO_PREAMBLE_LEN   (ARQO_HEADER_LEN + CC_SHA256_DIGEST_LENGTH + ARQO_IV_LEN + ARQO_META_ENC_LEN)


@interface Arq7EncryptedObjectDecryptor() {
    Arq7KeySet *_keySet;
}
@end


@implementation Arq7EncryptedObjectDecryptor

- (instancetype)initWithKeySet:(Arq7KeySet *)theKeySet {
    if (self = [super init]) {
        _keySet = theKeySet;
    }
    return self;
}

- (NSString *)errorDomain {
    return @"Arq7EncryptedObjectDecryptorErrorDomain";
}

+ (BOOL)isEncryptedData:(NSData *)theData {
    if ([theData length] < ARQO_HEADER_LEN) {
        return NO;
    }
    return strncmp((const char *)[theData bytes], ARQO_HEADER, ARQO_HEADER_LEN) == 0;
}

- (NSData *)decryptData:(NSData *)theData error:(NSError **)error {
    const unsigned char *bytes = (const unsigned char *)[theData bytes];
    NSUInteger dataLen = [theData length];

    if (dataLen < (NSUInteger)(ARQO_PREAMBLE_LEN + 1)) {
        SETNSERROR([self errorDomain], -1, @"encrypted object is too small (%lu bytes)", (unsigned long)dataLen);
        return nil;
    }

    // Check header.
    if (strncmp((const char *)bytes, ARQO_HEADER, ARQO_HEADER_LEN) != 0) {
        SETNSERROR([self errorDomain], -1, @"object does not have ARQO header");
        return nil;
    }

    // Verify HMAC-SHA256 of (masterIV + encryptedMetadata + ciphertext) using hmacKey.
    const unsigned char *hmacDataStart = bytes + ARQO_HEADER_LEN + CC_SHA256_DIGEST_LENGTH;
    NSUInteger hmacDataLen = dataLen - ARQO_HEADER_LEN - CC_SHA256_DIGEST_LENGTH;
    unsigned char calculatedHMAC[CC_SHA256_DIGEST_LENGTH];
    CCHmac(kCCHmacAlgSHA256,
           [_keySet.hmacKey bytes], kCCKeySizeAES256,
           hmacDataStart, hmacDataLen,
           calculatedHMAC);

    const unsigned char *storedHMAC = bytes + ARQO_HEADER_LEN;
    if (memcmp(calculatedHMAC, storedHMAC, CC_SHA256_DIGEST_LENGTH) != 0) {
        SETNSERROR([self errorDomain], ERROR_CORRUPT_BLOB, @"HMAC-SHA256 mismatch in ARQO object");
        return nil;
    }

    // Pointers into data.
    const unsigned char *masterIV        = bytes + ARQO_HEADER_LEN + CC_SHA256_DIGEST_LENGTH;
    const unsigned char *encryptedMeta   = masterIV + ARQO_IV_LEN;
    const unsigned char *ciphertext      = bytes + ARQO_PREAMBLE_LEN;
    NSUInteger ciphertextLen = dataLen - ARQO_PREAMBLE_LEN;

    // Decrypt metadata (dataIV + sessionKey) using encryptionKey + masterIV.
    unsigned char metaPlain[ARQO_META_PLAIN_LEN + ARQO_IV_LEN]; // +16 for PKCS7 safety
    size_t metaActualLen = 0;
    CCCryptorStatus status = CCCrypt(kCCDecrypt,
                                     kCCAlgorithmAES128,
                                     kCCOptionPKCS7Padding,
                                     [_keySet.encryptionKey bytes],
                                     kCCKeySizeAES256,
                                     masterIV,
                                     encryptedMeta,
                                     ARQO_META_ENC_LEN,
                                     metaPlain,
                                     sizeof(metaPlain),
                                     &metaActualLen);
    if (status != kCCSuccess) {
        SETNSERROR([self errorDomain], -1, @"failed to decrypt ARQO metadata (CCCrypt status %d)", (int)status);
        return nil;
    }
    if (metaActualLen != ARQO_META_PLAIN_LEN) {
        SETNSERROR([self errorDomain], -1, @"unexpected decrypted metadata length: %lu", (unsigned long)metaActualLen);
        return nil;
    }

    const unsigned char *dataIV     = metaPlain;
    const unsigned char *sessionKey = metaPlain + ARQO_IV_LEN;

    // Decrypt ciphertext using sessionKey + dataIV.
    NSMutableData *plaintext = [NSMutableData dataWithLength:ciphertextLen + ARQO_IV_LEN]; // enough for PKCS7
    size_t plaintextActualLen = 0;
    status = CCCrypt(kCCDecrypt,
                     kCCAlgorithmAES128,
                     kCCOptionPKCS7Padding,
                     sessionKey,
                     kCCKeySizeAES256,
                     dataIV,
                     ciphertext,
                     ciphertextLen,
                     [plaintext mutableBytes],
                     [plaintext length],
                     &plaintextActualLen);
    if (status != kCCSuccess) {
        SETNSERROR([self errorDomain], -1, @"failed to decrypt ARQO ciphertext (CCCrypt status %d)", (int)status);
        return nil;
    }
    [plaintext setLength:plaintextActualLen];
    return plaintext;
}
@end
