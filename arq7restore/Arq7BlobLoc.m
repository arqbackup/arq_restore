/*
 Arq7BlobLoc — port of arq7's BlobLoc.m.
 Changes from original: SETNSERROR_ARC → SETNSERROR, uses Arq7* types.
*/

#import "Arq7BlobLoc.h"
#import "StringIO.h"
#import "IntegerIO.h"
#import "BooleanIO.h"
#import "BufferedInputStream.h"


@implementation Arq7BlobLoc

- (instancetype)initWithBlobIdentifier:(NSString *)theBlobIdentifier
                              isPacked:(BOOL)theIsPacked
                           isLargePack:(BOOL)theIsLargePack
                          relativePath:(NSString *)theRelativePath
                                offset:(uint64_t)theOffset
                                length:(uint64_t)theLength
                  stretchEncryptionKey:(BOOL)doStretchEncryptionKey
                       compressionType:(Arq7CompressionType)theCompressionType {
    if (self = [super init]) {
        NSAssert(theBlobIdentifier != nil, @"blob identifier can't be nil");
        _blobIdentifier = theBlobIdentifier;
        _isPacked = theIsPacked;
        _isLargePack = theIsLargePack;
        NSAssert(theRelativePath != nil, @"relative path can't be nil");
        _relativePath = theRelativePath;
        _offset = theOffset;
        _length = theLength;
        _stretchEncryptionKey = doStretchEncryptionKey;
        _compressionType = theCompressionType;
    }
    return self;
}

- (instancetype)initWithJSON:(NSDictionary *)theJSON error:(NSError **)error {
    if (self = [super init]) {
        _blobIdentifier = [theJSON objectForKey:@"blobIdentifier"];
        if (_blobIdentifier == nil) {
            SETNSERROR([self errorDomain], -1, @"missing blob identifier");
            return nil;
        }
        _isPacked = [[theJSON objectForKey:@"isPacked"] boolValue];
        _isLargePack = [[theJSON objectForKey:@"isLargePack"] boolValue];
        _relativePath = [theJSON objectForKey:@"relativePath"];
        if (_relativePath == nil) {
            _relativePath = @"";
        }
        _offset = [[theJSON objectForKey:@"offset"] unsignedLongLongValue];
        _length = [[theJSON objectForKey:@"length"] unsignedLongLongValue];
        _stretchEncryptionKey = [[theJSON objectForKey:@"stretchEncryptionKey"] boolValue];
        _compressionType = (Arq7CompressionType)[[theJSON objectForKey:@"compressionType"] intValue];
    }
    return self;
}

- (instancetype)initWithBufferedInputStream:(BufferedInputStream *)theBIS
                                treeVersion:(int)theTreeVersion
                                      error:(NSError **)error {
    if (self = [super init]) {
        NSString *blobIdentifier = nil;
        BOOL isPacked = NO;
        BOOL isLargePack = NO;
        NSString *relativePath = nil;
        uint64_t offset = 0;
        uint64_t length = 0;
        BOOL stretchEncryptionKey = NO;
        uint32_t compressionType = 0;

        if (![StringIO read:&blobIdentifier from:theBIS error:error]) {
            return nil;
        }
        if (blobIdentifier == nil) {
            SETNSERROR([self errorDomain], -1, @"missing blob identifier");
            return nil;
        }
        if (![BooleanIO read:&isPacked from:theBIS error:error]) {
            return nil;
        }
        if (theTreeVersion >= 2) {
            if (![BooleanIO read:&isLargePack from:theBIS error:error]) {
                return nil;
            }
        }
        if (![StringIO read:&relativePath from:theBIS error:error]) {
            return nil;
        }
        if (relativePath == nil) {
            relativePath = @"";
        }
        if (![IntegerIO readUInt64:&offset from:theBIS error:error]) {
            return nil;
        }
        if (![IntegerIO readUInt64:&length from:theBIS error:error]) {
            return nil;
        }
        if (![BooleanIO read:&stretchEncryptionKey from:theBIS error:error]) {
            return nil;
        }
        if (![IntegerIO readUInt32:&compressionType from:theBIS error:error]) {
            return nil;
        }
        _blobIdentifier = blobIdentifier;
        _isPacked = isPacked;
        _isLargePack = isLargePack;
        _relativePath = relativePath;
        _offset = offset;
        _length = length;
        _stretchEncryptionKey = stretchEncryptionKey;
        _compressionType = (Arq7CompressionType)compressionType;

        if (_offset > 1000000000) {
            SETNSERROR([self errorDomain], -1, @"absurd offset value in Arq7BlobLoc");
            return nil;
        }
        if (_length > 1000000000) {
            SETNSERROR([self errorDomain], -1, @"absurd length value in Arq7BlobLoc");
            return nil;
        }
    }
    return self;
}

- (NSString *)errorDomain {
    return @"Arq7BlobLocErrorDomain";
}


#pragma mark NSCopying
- (nonnull id)copyWithZone:(nullable NSZone *)zone {
    return [[Arq7BlobLoc alloc] initWithBlobIdentifier:self.blobIdentifier
                                              isPacked:self.isPacked
                                           isLargePack:self.isLargePack
                                          relativePath:self.relativePath
                                                offset:self.offset
                                                length:self.length
                                  stretchEncryptionKey:self.stretchEncryptionKey
                                       compressionType:self.compressionType];
}


#pragma mark NSObject
- (BOOL)isEqual:(id)other {
    if (other == self) return YES;
    if (other == nil || ![other isKindOfClass:[self class]]) return NO;
    Arq7BlobLoc *o = (Arq7BlobLoc *)other;
    return [o.blobIdentifier isEqual:self.blobIdentifier]
        && o.isPacked == self.isPacked
        && o.isLargePack == self.isLargePack
        && [o.relativePath isEqual:self.relativePath]
        && o.offset == self.offset
        && o.length == self.length
        && o.stretchEncryptionKey == self.stretchEncryptionKey
        && o.compressionType == self.compressionType;
}
- (NSUInteger)hash {
    return [_blobIdentifier hash];
}
- (NSString *)description {
    NSString *packDesc = @"";
    if (self.isLargePack) {
        packDesc = @",largepacked";
    } else if (self.isPacked) {
        packDesc = @",packed";
    }
    return [NSString stringWithFormat:@"<%@ %@:%qu-%qu%@>",
            self.blobIdentifier, self.relativePath,
            self.offset, (self.offset + self.length), packDesc];
}
@end
