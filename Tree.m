//
//  Tree.m
//  Backup
//
//  Created by Stefan Reitshamer on 3/25/09.
//  Copyright 2009 PhotoMinds LLC. All rights reserved.
//

#import "StringIO.h"
#import "IntegerIO.h"
#import "BooleanIO.h"
#import "Node.h"
#import "Tree.h"
#import "Blob.h"
#import "DataInputStream.h"
#import "SetNSError.h"
#import "RegexKitLite.h"
#import "NSErrorCodes.h"
#import "BufferedInputStream.h"
#import "NSData-Gzip.h"
#import "GunzipInputStream.h"
#import "BlobKey.h"
#import "NSObject_extra.h"

@interface Tree (internal)
- (BOOL)readHeader:(BufferedInputStream *)is error:(NSError **)error;
@end

@implementation Tree
@synthesize xattrsAreCompressed, xattrsBlobKey, xattrsSize, aclIsCompressed, aclBlobKey, uid, gid, mode, mtime_sec, mtime_nsec, flags, finderFlags, extendedFinderFlags, st_dev, treeVersion, st_rdev;
@synthesize ctime_sec, ctime_nsec, createTime_sec, createTime_nsec, st_nlink, st_ino, st_blocks, st_blksize;
@synthesize aggregateSizeOnDisk;

+ (NSString *)errorDomain {
    return @"TreeErrorDomain";
}
- (id)init {
    if (self = [super init]) {
        nodes = [[NSMutableDictionary alloc] init];
    }
    return self;
}
- (id)initWithBufferedInputStream:(BufferedInputStream *)is error:(NSError **)error {
	if (self = [super init]) {
        if (![self readHeader:is error:error]) {
            [self release];
            return nil;
        }
        if (treeVersion >= 12) {
            if (![BooleanIO read:&xattrsAreCompressed from:is error:error]
                || ![BooleanIO read:&aclIsCompressed from:is error:error]) {
                [self release];
                return nil;
            }
        }
        
        NSString *xattrsSHA1 = nil;
        BOOL xattrsStretchedKey = NO;
        NSString *aclSHA1 = nil;
        BOOL aclStretchedKey = NO;
        BOOL ret = [StringIO read:&xattrsSHA1 from:is error:error]
        && (treeVersion < 14 || [BooleanIO read:&xattrsStretchedKey from:is error:error])
        && [IntegerIO readUInt64:&xattrsSize from:is error:error]
        &&[StringIO read:&aclSHA1 from:is error:error]
        && (treeVersion < 14 || [BooleanIO read:&aclStretchedKey from:is error:error])
        && [IntegerIO readInt32:&uid from:is error:error]
        && [IntegerIO readInt32:&gid from:is error:error]
        && [IntegerIO readInt32:&mode from:is error:error]
        && [IntegerIO readInt64:&mtime_sec from:is error:error]
        && [IntegerIO readInt64:&mtime_nsec from:is error:error]
        && [IntegerIO readInt64:&flags from:is error:error]
        && [IntegerIO readInt32:&finderFlags from:is error:error]
        && [IntegerIO readInt32:&extendedFinderFlags from:is error:error]
        && [IntegerIO readInt32:&st_dev from:is error:error]
        && [IntegerIO readInt32:&st_ino from:is error:error]
        && [IntegerIO readUInt32:&st_nlink from:is error:error]
        && [IntegerIO readInt32:&st_rdev from:is error:error]
        && [IntegerIO readInt64:&ctime_sec from:is error:error]
        && [IntegerIO readInt64:&ctime_nsec from:is error:error]
        && [IntegerIO readInt64:&st_blocks from:is error:error]
        && [IntegerIO readUInt32:&st_blksize from:is error:error];
        if (!ret) {
            goto initError;
        }
        if (xattrsSHA1 != nil) {
            xattrsBlobKey = [[BlobKey alloc] initWithSHA1:xattrsSHA1 stretchEncryptionKey:xattrsStretchedKey];
        }
        if (aclSHA1 != nil) {
            aclBlobKey = [[BlobKey alloc] initWithSHA1:aclSHA1 stretchEncryptionKey:aclStretchedKey];
        }
        
        if (treeVersion >= 11) {
            if (![IntegerIO readUInt64:&aggregateSizeOnDisk from:is error:error]) {
                goto initError;
            }
        }
        if (treeVersion >= 15) {
            if (![IntegerIO readInt64:&createTime_sec from:is error:error]
                || ![IntegerIO readInt64:&createTime_nsec from:is error:error]) {
                goto initError;
            }
        }        
        
        unsigned int nodeCount;
        if (![IntegerIO readUInt32:&nodeCount from:is error:error]) {
            goto initError;
        }
        nodes = [[NSMutableDictionary alloc] init];
        for (unsigned int i = 0; i < nodeCount; i++) {
            NSString *nodeName;
            if (![StringIO read:&nodeName from:is error:error]) {
                goto initError;
            }
            Node *node = [[Node alloc] initWithInputStream:is treeVersion:treeVersion error:error];
            if (!node) {
                goto initError;
            }
            [nodes setObject:node forKey:nodeName];
            [node release];
        }
        goto initDone;
    initError:
        [self release];
        self = nil;
	}
initDone:
	return self;
}
- (void)dealloc {
    [xattrsBlobKey release];
    [aclBlobKey release];
	[nodes release];
	[super dealloc];
}
- (NSArray *)childNodeNames {
	return [nodes allKeys];
}
- (Node *)childNodeWithName:(NSString *)name {
	return [nodes objectForKey:name];
}
- (BOOL)containsNodeNamed:(NSString *)name {
	return [nodes objectForKey:name] != nil;
}
- (NSDictionary *)nodes {
    return nodes;
}
- (Blob *)toBlob {
    NSMutableData *data = [[NSMutableData alloc] init];
    [BooleanIO write:xattrsAreCompressed to:data];
    [BooleanIO write:aclIsCompressed to:data];
    [StringIO write:[xattrsBlobKey sha1] to:data];
    [BooleanIO write:[xattrsBlobKey stretchEncryptionKey] to:data];
    [IntegerIO writeUInt64:xattrsSize to:data];
    [StringIO write:[aclBlobKey sha1] to:data];
    [BooleanIO write:[aclBlobKey stretchEncryptionKey] to:data];
    [IntegerIO writeInt32:uid to:data];
    [IntegerIO writeInt32:gid to:data];
    [IntegerIO writeInt32:mode to:data];
    [IntegerIO writeInt64:mtime_sec to:data];
    [IntegerIO writeInt64:mtime_nsec to:data];
    [IntegerIO writeInt64:flags to:data];
    [IntegerIO writeInt32:finderFlags to:data];
    [IntegerIO writeInt32:extendedFinderFlags to:data];
    [IntegerIO writeInt32:st_dev to:data];
    [IntegerIO writeInt32:st_ino to:data];
    [IntegerIO writeUInt32:st_nlink to:data];
    [IntegerIO writeInt32:st_rdev to:data];
    [IntegerIO writeInt64:ctime_sec to:data];
    [IntegerIO writeInt64:ctime_nsec to:data];
    [IntegerIO writeInt64:st_blocks to:data];
    [IntegerIO writeUInt32:st_blksize to:data];
    [IntegerIO writeUInt64:aggregateSizeOnDisk to:data];
    
    [IntegerIO writeUInt32:(uint32_t)[nodes count] to:data];
    NSMutableArray *nodeNames = [NSMutableArray arrayWithArray:[nodes allKeys]];
    [nodeNames sortUsingSelector:@selector(compare:)];
    for (NSString *nodeName in nodeNames) {
        [StringIO write:nodeName to:data];
        Node *node = [nodes objectForKey:nodeName];
        [node writeToData:data];
    }
    
    char header[TREE_HEADER_LENGTH + 1];
    sprintf(header, "TreeV%03d", CURRENT_TREE_VERSION);
    NSMutableData *completeData = [[NSMutableData alloc] init];
    [completeData appendBytes:header length:TREE_HEADER_LENGTH];

    [completeData appendBytes:[data bytes] length:[data length]];
    
    Blob *ret =[[[Blob alloc] initWithData:completeData mimeType:@"binary/octet-stream" downloadName:@"Tree" dataDescription:@"tree"] autorelease];
    [completeData release];
    [data release];
    return ret;
}

#pragma mark NSObject
- (BOOL)isEqual:(id)object {
    if (![object isKindOfClass:[Tree class]]) {
        return NO;
    }
    Tree *other = (Tree *)object;
    return treeVersion == [other treeVersion] 
    && xattrsAreCompressed == [other xattrsAreCompressed]
    && [NSObject equalObjects:xattrsBlobKey and:[other xattrsBlobKey]]
    && xattrsSize == [other xattrsSize]
    && aclIsCompressed == [other aclIsCompressed]
    && [NSObject equalObjects:aclBlobKey and:[other aclBlobKey]]
    && uid == [other uid]
    && gid == [other gid]
    && mode == [other mode]
    && mtime_sec == [other mtime_sec]
    && mtime_nsec == [other mtime_nsec]
    && flags == [other flags]
    && finderFlags == [other finderFlags]
    && extendedFinderFlags == [other extendedFinderFlags]
    && st_dev == [other st_dev]
    && st_ino == [other st_ino]
    && st_nlink == [other st_nlink]
    && st_rdev == [other st_rdev]
    && ctime_sec == [other ctime_sec]
    && ctime_nsec == [other ctime_nsec]
    && createTime_sec == [other createTime_sec]
    && createTime_nsec == [other createTime_nsec]
    && st_blocks == [other st_blocks]
    && st_blksize == [other st_blksize]
    && aggregateSizeOnDisk == [other aggregateSizeOnDisk]
    && [nodes isEqual:[other nodes]];
}
- (NSUInteger)hash {
    return (NSUInteger)treeVersion + [nodes hash];
}
@end

@implementation Tree (internal)
- (BOOL)readHeader:(BufferedInputStream *)is error:(NSError **)error {
    BOOL ret = NO;
    unsigned char *buf = (unsigned char *)malloc(TREE_HEADER_LENGTH);
    if (![is readExactly:TREE_HEADER_LENGTH into:buf error:error]) {
        goto readHeader_error;
    }
    NSString *header = [[[NSString alloc] initWithBytes:buf length:TREE_HEADER_LENGTH encoding:NSASCIIStringEncoding] autorelease];
    NSRange versionRange = [header rangeOfRegex:@"^TreeV(\\d{3})$" capture:1];
    treeVersion = 0;
    if (versionRange.location != NSNotFound) {
        NSNumberFormatter *nf = [[NSNumberFormatter alloc] init];
        NSNumber *number = [nf numberFromString:[header substringWithRange:versionRange]];
        treeVersion = [number intValue];
        [nf release];
    }
    if (treeVersion < 10) {
        SETNSERROR([Tree errorDomain], ERROR_INVALID_OBJECT_VERSION, @"invalid Tree header: %@", header);
        goto readHeader_error;
    }
    if (treeVersion == 13) {
        SETNSERROR([Tree errorDomain], ERROR_INVALID_OBJECT_VERSION, @"invalid Tree version 13");
        goto readHeader_error;
    }
    ret = YES;
readHeader_error:
    free(buf);
    return ret;
}
@end
