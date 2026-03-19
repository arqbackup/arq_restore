/*
 Arq7KeySet — decrypts the encryptedkeyset.dat file from an Arq 7 backup set.
 Uses CommonCrypto (ships with macOS/Xcode — no OpenSSL dependency).
*/

@interface Arq7KeySet : NSObject

// Decrypts encryptedkeyset.dat bytes using the given password.
- (instancetype)initWithEncryptedData:(NSData *)theEncryptedData
                     encryptionPassword:(NSString *)thePassword
                                  error:(NSError **)error;

// 32-byte master encryption key (AES-256)
@property (readonly) NSData *encryptionKey;
// 32-byte master HMAC key (HMAC-SHA256)
@property (readonly) NSData *hmacKey;
@end
