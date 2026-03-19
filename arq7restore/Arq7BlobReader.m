#import "Arq7BlobReader.h"
#import "Arq7BlobLoc.h"
#import "Arq7KeySet.h"
#import "Arq7Tree.h"
#import "Arq7EncryptedObjectDecryptor.h"
#import "TargetConnection.h"
#import "DataInputStream.h"
#import "BufferedInputStream.h"
#include "lz4.h"
#include <libkern/OSByteOrder.h>


@interface Arq7BlobReader() {
    NSString *_planUUID;
    TargetConnection *_conn;
    Arq7KeySet *_keySet;
    id <TargetConnectionDelegate> _delegate;
}
@end


@implementation Arq7BlobReader

- (instancetype)initWithPlanUUID:(NSString *)thePlanUUID
                targetConnection:(TargetConnection *)theConn
                          keySet:(Arq7KeySet *)theKeySet
                        delegate:(id <TargetConnectionDelegate>)theDelegate {
    if (self = [super init]) {
        _planUUID = thePlanUUID;
        _conn = theConn;
        _keySet = theKeySet;
        _delegate = theDelegate;
    }
    return self;
}

- (NSString *)errorDomain {
    return @"Arq7BlobReaderErrorDomain";
}

- (NSData *)dataForBlobLoc:(Arq7BlobLoc *)theBlobLoc error:(NSError **)error {
    NSData *rawData = nil;

    // Build the full relative path (relative to target root).
    NSString *relativePath = [NSString stringWithFormat:@"%@/%@/%@", [_conn pathPrefix], _planUUID, theBlobLoc.relativePath];

    if (theBlobLoc.isPacked) {
        // Read a slice from a pack file.
        NSRange range = NSMakeRange((NSUInteger)theBlobLoc.offset, (NSUInteger)theBlobLoc.length);
        rawData = [_conn contentsOfRange:range ofFileAtPath:relativePath delegate:_delegate error:error];
    } else {
        // Read the standalone object file.
        rawData = [_conn contentsOfFileAtPath:relativePath delegate:_delegate error:error];
    }

    if (rawData == nil) {
        return nil;
    }

    // Decrypt if ARQO-prefixed.
    if ([Arq7EncryptedObjectDecryptor isEncryptedData:rawData]) {
        if (_keySet == nil) {
            SETNSERROR([self errorDomain], ERROR_INVALID_PASSWORD, @"blob is encrypted but no key set provided");
            return nil;
        }
        Arq7EncryptedObjectDecryptor *dec = [[Arq7EncryptedObjectDecryptor alloc] initWithKeySet:_keySet];
        rawData = [dec decryptData:rawData error:error];
        if (rawData == nil) {
            return nil;
        }
    }

    // Decompress if needed.
    if (theBlobLoc.compressionType == kArq7CompressionTypeLZ4) {
        rawData = [self lz4Decompress:rawData error:error];
        if (rawData == nil) {
            return nil;
        }
    }
    // kArq7CompressionTypeNone and kArq7CompressionTypeGzip — return as-is (gzip not currently used in Arq7).

    return rawData;
}

- (Arq7Tree *)treeForBlobLoc:(Arq7BlobLoc *)theBlobLoc error:(NSError **)error {
    NSData *data = [self dataForBlobLoc:theBlobLoc error:error];
    if (data == nil) {
        return nil;
    }
    DataInputStream *dis = [[DataInputStream alloc] initWithData:data description:@"tree data"];
    BufferedInputStream *bis = [[BufferedInputStream alloc] initWithUnderlyingStream:dis];
    return [[Arq7Tree alloc] initWithBufferedInputStream:bis error:error];
}


#pragma mark internal

- (NSData *)lz4Decompress:(NSData *)theData error:(NSError **)error {
    if ([theData length] < 5) {
        SETNSERROR([self errorDomain], -1, @"data too short for LZ4 decompression (%lu bytes)", (unsigned long)[theData length]);
        return nil;
    }
    const unsigned char *bytes = (const unsigned char *)[theData bytes];
    uint32_t nboSize = 0;
    memcpy(&nboSize, bytes, 4);
    int originalSize = (int)OSSwapBigToHostInt32(nboSize);
    if (originalSize < 0 || originalSize > 512 * 1024 * 1024) {
        SETNSERROR([self errorDomain], -1, @"invalid LZ4 original size: %d", originalSize);
        return nil;
    }
    if (originalSize == 0) {
        return [NSData data];
    }
    NSMutableData *ret = [NSMutableData dataWithLength:(NSUInteger)originalSize];
    int compressedSize = (int)[theData length] - 4;
    int inflated = LZ4_decompress_safe((const char *)(bytes + 4),
                                       (char *)[ret mutableBytes],
                                       compressedSize,
                                       originalSize);
    if (inflated != originalSize) {
        SETNSERROR([self errorDomain], -1, @"LZ4 decompression error (got %d, expected %d)", inflated, originalSize);
        return nil;
    }
    return ret;
}
@end
