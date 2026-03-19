/*
 Arq7EncryptedObjectDecryptor — decrypts ARQO-prefixed data using an Arq7KeySet.
 Port of arq7's Decryptor class, simplified for arq_restore.
*/

@class Arq7KeySet;

@interface Arq7EncryptedObjectDecryptor : NSObject

- (instancetype)initWithKeySet:(Arq7KeySet *)theKeySet;

// Returns decrypted plaintext from an ARQO-prefixed NSData, or nil on error.
- (NSData *)decryptData:(NSData *)theData error:(NSError **)error;

// Returns YES if data has the ARQO header (is encrypted).
+ (BOOL)isEncryptedData:(NSData *)theData;
@end
