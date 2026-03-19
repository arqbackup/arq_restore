/*
 Arq7BlobReader — fetches and decodes blob data given an Arq7BlobLoc.
 Handles packed vs. standalone blobs, LZ4 decompression, and ARQO decryption.
*/

@class Arq7BlobLoc;
@class Arq7KeySet;
@class Arq7Tree;
@class TargetConnection;
@protocol TargetConnectionDelegate;

@interface Arq7BlobReader : NSObject

- (instancetype)initWithPlanUUID:(NSString *)thePlanUUID
                targetConnection:(TargetConnection *)theConn
                          keySet:(Arq7KeySet *)theKeySet
                        delegate:(id <TargetConnectionDelegate>)theDelegate;

// Fetches, decrypts, and decompresses raw blob data.
- (NSData *)dataForBlobLoc:(Arq7BlobLoc *)theBlobLoc error:(NSError **)error;

// Convenience: reads and parses a Tree from a blob loc.
- (Arq7Tree *)treeForBlobLoc:(Arq7BlobLoc *)theBlobLoc error:(NSError **)error;
@end
