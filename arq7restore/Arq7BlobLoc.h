/*
 Arq7BlobLoc — direct port of arq7's BlobLoc.h for use in arq_restore.
 Uses Arq7* prefix to avoid conflicts with existing arq_restore types.
*/

#import "Arq7Types.h"
@class BufferedInputStream;

@interface Arq7BlobLoc : NSObject <NSCopying>

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithBlobIdentifier:(NSString *)theBlobIdentifier
                              isPacked:(BOOL)theIsPacked
                           isLargePack:(BOOL)theIsLargePack
                          relativePath:(NSString *)theRelativePath
                                offset:(uint64_t)theOffset
                                length:(uint64_t)theLength
                  stretchEncryptionKey:(BOOL)doStretchEncryptionKey
                       compressionType:(Arq7CompressionType)theCompressionType;
- (instancetype)initWithJSON:(NSDictionary *)theJSON error:(NSError **)error;
- (instancetype)initWithBufferedInputStream:(BufferedInputStream *)theBIS
                                treeVersion:(int)theTreeVersion
                                      error:(NSError **)error;

@property (readonly) NSString *blobIdentifier;
@property (readonly) BOOL isPacked;
@property (readonly) BOOL isLargePack;
@property (readonly) NSString *relativePath;
@property (readonly) uint64_t offset;
@property (readonly) uint64_t length;
@property (readonly) BOOL stretchEncryptionKey;
@property (readonly) Arq7CompressionType compressionType;
@end
