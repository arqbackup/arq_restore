/*
 Arq7KeySet — port of arq7's KeySet.m decryption path.
 Uses CommonCrypto only (no OpenSSL).
*/

#import <CommonCrypto/CommonHMAC.h>
#import <CommonCrypto/CommonKeyDerivation.h>
#import <CommonCrypto/CommonDigest.h>
#import <CommonCrypto/CommonCryptor.h>
#import "Arq7KeySet.h"
#import "DataInputStream.h"
#import "BufferedInputStream.h"
#import "IntegerIO.h"


#define ARQ7_KEYSET_HEADER          "ARQ_ENCRYPTED_MASTER_KEYS"
#define ARQ7_KEYSET_HEADER_LEN      (25)
#define ARQ7_KEYSET_SALT_LEN        (8)
#define ARQ7_KEYSET_IV_LEN          (16)
#define ARQ7_KEY_DERIVATION_ROUNDS  (200000)
#define ARQ7_DERIVED_KEY_LEN        (64)   // 32-byte AES key + 32-byte HMAC key
#define ARQ7_BUFFERSIZE             (65536)


@implementation Arq7KeySet

- (instancetype)initWithEncryptedData:(NSData *)theEncryptedData
                     encryptionPassword:(NSString *)thePassword
                                  error:(NSError **)error {
    if (self = [super init]) {
        const unsigned char *bytes = (const unsigned char *)[theEncryptedData bytes];
        NSUInteger dataLen = [theEncryptedData length];

        // Minimum length check.
        NSUInteger minLen = ARQ7_KEYSET_HEADER_LEN + ARQ7_KEYSET_SALT_LEN + CC_SHA256_DIGEST_LENGTH + ARQ7_KEYSET_IV_LEN + 1;
        if (dataLen < minLen) {
            SETNSERROR([self errorDomain], -1, @"encryptedkeyset.dat is too short (%lu bytes)", (unsigned long)dataLen);
            return nil;
        }

        // Check header.
        if (strncmp((const char *)bytes, ARQ7_KEYSET_HEADER, ARQ7_KEYSET_HEADER_LEN) != 0) {
            SETNSERROR([self errorDomain], -1, @"encryptedkeyset.dat has invalid header");
            return nil;
        }

        // Extract salt (8 bytes after header).
        const unsigned char *saltBytes = bytes + ARQ7_KEYSET_HEADER_LEN;

        // Derive 64-byte key from password + salt using PBKDF2-SHA256.
        NSData *passwordData = [thePassword dataUsingEncoding:NSUTF8StringEncoding];
        unsigned char derivedKey[ARQ7_DERIVED_KEY_LEN];
        CCKeyDerivationPBKDF(kCCPBKDF2,
                             (const char *)[passwordData bytes],
                             [passwordData length],
                             saltBytes,
                             ARQ7_KEYSET_SALT_LEN,
                             kCCPRFHmacAlgSHA256,
                             ARQ7_KEY_DERIVATION_ROUNDS,
                             derivedKey,
                             ARQ7_DERIVED_KEY_LEN);

        // Split derived key: first 32 bytes = AES key, second 32 bytes = HMAC key.
        const unsigned char *aesKey  = derivedKey;
        const unsigned char *hmacKey = derivedKey + kCCKeySizeAES256;

        // Verify HMAC-SHA256 of (IV + ciphertext) using derived HMAC key.
        // HMAC covers everything after header + salt + stored-HMAC, i.e. from IV onwards.
        const unsigned char *hmacStart = bytes + ARQ7_KEYSET_HEADER_LEN + ARQ7_KEYSET_SALT_LEN + CC_SHA256_DIGEST_LENGTH;
        NSUInteger hmacDataLen = dataLen - (ARQ7_KEYSET_HEADER_LEN + ARQ7_KEYSET_SALT_LEN + CC_SHA256_DIGEST_LENGTH);

        unsigned char calculatedHMAC[CC_SHA256_DIGEST_LENGTH];
        CCHmac(kCCHmacAlgSHA256, hmacKey, kCCKeySizeAES256, hmacStart, hmacDataLen, calculatedHMAC);

        const unsigned char *storedHMAC = bytes + ARQ7_KEYSET_HEADER_LEN + ARQ7_KEYSET_SALT_LEN;
        if (memcmp(calculatedHMAC, storedHMAC, CC_SHA256_DIGEST_LENGTH) != 0) {
            SETNSERROR([self errorDomain], ERROR_INVALID_PASSWORD, @"incorrect encryption password for encryptedkeyset.dat");
            return nil;
        }

        // Extract IV (16 bytes after header + salt + HMAC).
        const unsigned char *iv = bytes + ARQ7_KEYSET_HEADER_LEN + ARQ7_KEYSET_SALT_LEN + CC_SHA256_DIGEST_LENGTH;

        // Decrypt master keys using derived AES key + IV.
        const unsigned char *ciphertext = iv + ARQ7_KEYSET_IV_LEN;
        NSUInteger ciphertextLen = dataLen - (ARQ7_KEYSET_HEADER_LEN + ARQ7_KEYSET_SALT_LEN + CC_SHA256_DIGEST_LENGTH + ARQ7_KEYSET_IV_LEN);

        NSMutableData *plaintext = [NSMutableData dataWithLength:ARQ7_BUFFERSIZE];
        size_t plaintextActualLen = 0;
        CCCryptorStatus status = CCCrypt(kCCDecrypt,
                                         kCCAlgorithmAES128,
                                         kCCOptionPKCS7Padding,
                                         aesKey,
                                         kCCKeySizeAES256,
                                         iv,
                                         ciphertext,
                                         ciphertextLen,
                                         [plaintext mutableBytes],
                                         [plaintext length],
                                         &plaintextActualLen);
        if (status != kCCSuccess) {
            SETNSERROR([self errorDomain], -1, @"failed to decrypt encryptedkeyset.dat (CCCrypt status %d)", (int)status);
            return nil;
        }
        [plaintext setLength:plaintextActualLen];

        // Parse plaintext: version(uint32) + DataIO(encryptionKey) + DataIO(hmacKey) + DataIO(blobIdSalt)
        // DataIO format: uint64 length + bytes
        DataInputStream *dis = [[DataInputStream alloc] initWithData:plaintext description:@"keyset plaintext"];
        BufferedInputStream *bis = [[BufferedInputStream alloc] initWithUnderlyingStream:dis];

        uint32_t encVersion = 0;
        if (![IntegerIO readUInt32:&encVersion from:bis error:error]) {
            return nil;
        }

        // Read encryptionKey (DataIO: uint64 length + bytes)
        uint64_t encKeyLen = 0;
        if (![IntegerIO readUInt64:&encKeyLen from:bis error:error]) {
            return nil;
        }
        NSData *encKeyBytes = [bis readExactly:(NSUInteger)encKeyLen error:error];
        if (encKeyBytes == nil) {
            return nil;
        }
        _encryptionKey = encKeyBytes;

        // Read hmacKey
        uint64_t hmacKeyLen = 0;
        if (![IntegerIO readUInt64:&hmacKeyLen from:bis error:error]) {
            return nil;
        }
        NSData *hmacKeyBytes = [bis readExactly:(NSUInteger)hmacKeyLen error:error];
        if (hmacKeyBytes == nil) {
            return nil;
        }
        _hmacKey = hmacKeyBytes;

        // Validate key sizes.
        if ([_encryptionKey length] != kCCKeySizeAES256) {
            SETNSERROR([self errorDomain], -1, @"unexpected encryption key length: %lu (expected 32)", (unsigned long)[_encryptionKey length]);
            return nil;
        }
        if ([_hmacKey length] != kCCKeySizeAES256) {
            // Some versions store empty hmac key; tolerate that.
            if ([_hmacKey length] != 0) {
                SETNSERROR([self errorDomain], -1, @"unexpected HMAC key length: %lu", (unsigned long)[_hmacKey length]);
                return nil;
            }
        }
    }
    return self;
}

- (NSString *)errorDomain {
    return @"Arq7KeySetErrorDomain";
}
@end
