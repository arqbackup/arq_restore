//
//  Node.m
//  s3print
//
//  Created by Stefan Reitshamer on 4/10/09.
//  Copyright 2009 PhotoMinds LLC. All rights reserved.
//

#include <sys/stat.h>
#import "Node.h"
#import "BooleanIO.h"
#import "IntegerIO.h"
#import "StringIO.h"
#import "BufferedInputStream.h"
#import "BlobKey.h"
#import "NSObject_extra.h"

@implementation Node
@synthesize isTree, uncompressedDataSize, thumbnailBlobKey, previewBlobKey, xattrsBlobKey, xattrsSize, aclBlobKey, uid, gid, mode, mtime_sec, mtime_nsec, flags, finderFlags, extendedFinderFlags, finderFileType, finderFileCreator, isFileExtensionHidden, st_dev, treeVersion, st_rdev;
@synthesize ctime_sec, ctime_nsec, createTime_sec, createTime_nsec, st_nlink, st_ino, st_blocks, st_blksize;
@dynamic treeBlobKey, dataBlobKeys;
@synthesize dataAreCompressed, xattrsAreCompressed, aclIsCompressed;

- (id)initWithInputStream:(BufferedInputStream *)is treeVersion:(int)theTreeVersion error:(NSError **)error {
    if (self = [super init]) {
        treeVersion = theTreeVersion;
        dataBlobKeys = [[NSMutableArray alloc] init];

        if (![BooleanIO read:&isTree from:is error:error]) {
            [self release];
            return nil;
        }
        
        if (treeVersion >= 12) {
            if (![BooleanIO read:&dataAreCompressed from:is error:error]
                || ![BooleanIO read:&xattrsAreCompressed from:is error:error]
                || ![BooleanIO read:&aclIsCompressed from:is error:error]) {
                [self release];
                return nil;
            }
        }
        
        int dataBlobKeysCount;
        if (![IntegerIO readInt32:&dataBlobKeysCount from:is error:error]) {
            [self release];
            return nil;
        }
        for (int i = 0; i < dataBlobKeysCount; i++) {
            NSString *dataSHA1;
            BOOL stretchEncryptionKey = NO;
            if (![StringIO read:&dataSHA1 from:is error:error]) {
                [self release];
                return nil;
            }            
            if (treeVersion >= 14 && ![BooleanIO read:&stretchEncryptionKey from:is error:error]) {
                [self release];
                return nil;
            }
            BlobKey *bk = [[BlobKey alloc] initWithSHA1:dataSHA1 stretchEncryptionKey:stretchEncryptionKey];
            [dataBlobKeys addObject:bk];
            [bk release];
        }
        NSString *thumbnailSHA1 = nil;
        BOOL thumbnailStretchedKey = NO;
        NSString *previewSHA1 = nil;
        BOOL previewStretchedKey = NO;
        NSString *xattrsSHA1 = nil;
        BOOL xattrsStretchedKey = NO;
        NSString *aclSHA1 = nil;
        BOOL aclStretchedKey = NO;
        BOOL ret = [IntegerIO readUInt64:&uncompressedDataSize from:is error:error]
        && [StringIO read:&thumbnailSHA1 from:is error:error]
        && (treeVersion < 14 || [BooleanIO read:&thumbnailStretchedKey from:is error:error])
        && [StringIO read:&previewSHA1 from:is error:error]
        && (treeVersion < 14 || [BooleanIO read:&previewStretchedKey from:is error:error])
        && [StringIO read:&xattrsSHA1 from:is error:error]
        && (treeVersion < 14 || [BooleanIO read:&xattrsStretchedKey from:is error:error])
        && [IntegerIO readUInt64:&xattrsSize from:is error:error]
        && [StringIO read:&aclSHA1 from:is error:error]
        && (treeVersion < 14 || [BooleanIO read:&aclStretchedKey from:is error:error])
        && [IntegerIO readInt32:&uid from:is error:error]
        && [IntegerIO readInt32:&gid from:is error:error]
        && [IntegerIO readInt32:&mode from:is error:error]
        && [IntegerIO readInt64:&mtime_sec from:is error:error]
        && [IntegerIO readInt64:&mtime_nsec from:is error:error]
        && [IntegerIO readInt64:&flags from:is error:error]
        && [IntegerIO readInt32:&finderFlags from:is error:error]
        && [IntegerIO readInt32:&extendedFinderFlags from:is error:error]
        && [StringIO read:&finderFileType from:is error:error]
        && [StringIO read:&finderFileCreator from:is error:error]
        && [BooleanIO read:&isFileExtensionHidden from:is error:error]
        && [IntegerIO readInt32:&st_dev from:is error:error]
        && [IntegerIO readInt32:&st_ino from:is error:error]
        && [IntegerIO readUInt32:&st_nlink from:is error:error]
        && [IntegerIO readInt32:&st_rdev from:is error:error]
        && [IntegerIO readInt64:&ctime_sec from:is error:error]
        && [IntegerIO readInt64:&ctime_nsec from:is error:error]
        && [IntegerIO readInt64:&createTime_sec from:is error:error]
        && [IntegerIO readInt64:&createTime_nsec from:is error:error]
        && [IntegerIO readInt64:&st_blocks from:is error:error]
        && [IntegerIO readUInt32:&st_blksize from:is error:error];
        [finderFileType retain];
        [finderFileCreator retain];
        if (!ret) {
            [self release];
            return nil;
        }
        if (thumbnailSHA1 != nil) {
            thumbnailBlobKey = [[BlobKey alloc] initWithSHA1:thumbnailSHA1 stretchEncryptionKey:thumbnailStretchedKey];
        }
        if (previewSHA1 != nil) {
            previewBlobKey = [[BlobKey alloc] initWithSHA1:previewSHA1 stretchEncryptionKey:previewStretchedKey];
        }
        if (xattrsSHA1 != nil) {
            xattrsBlobKey = [[BlobKey alloc] initWithSHA1:xattrsSHA1 stretchEncryptionKey:xattrsStretchedKey];
        }
        if (aclSHA1 != nil) {
            aclBlobKey = [[BlobKey alloc] initWithSHA1:aclSHA1 stretchEncryptionKey:aclStretchedKey];
        }
    }
    return self;
}
- (void)dealloc {
	[dataBlobKeys release];
    [thumbnailBlobKey release];
    [previewBlobKey release];
	[xattrsBlobKey release];
	[aclBlobKey release];
	[finderFileType release];
	[finderFileCreator release];
	[super dealloc];
}
- (BlobKey *)treeBlobKey {
    NSAssert(isTree, @"must be a Tree");
    return [dataBlobKeys objectAtIndex:0];
}
- (NSArray *)dataBlobKeys {
    return dataBlobKeys;
}
- (BOOL)dataMatchesStatData:(struct stat *)st {
    return (st->st_mtimespec.tv_sec == mtime_sec && st->st_mtimespec.tv_nsec == mtime_nsec && st->st_size == uncompressedDataSize);
}
- (void)writeToData:(NSMutableData *)data {
    [BooleanIO write:isTree to:data];
    [BooleanIO write:dataAreCompressed to:data];
    [BooleanIO write:xattrsAreCompressed to:data];
    [BooleanIO write:aclIsCompressed to:data];
    [IntegerIO writeInt32:(int32_t)[dataBlobKeys count] to:data];
    for (BlobKey *dataBlobKey in dataBlobKeys) {
        [StringIO write:[dataBlobKey sha1] to:data];
        [BooleanIO write:[dataBlobKey stretchEncryptionKey] to:data];
    }
    [IntegerIO writeUInt64:uncompressedDataSize to:data];
    [StringIO write:[thumbnailBlobKey sha1] to:data];
    [BooleanIO write:[thumbnailBlobKey stretchEncryptionKey] to:data];
    [StringIO write:[previewBlobKey sha1] to:data];
    [BooleanIO write:[previewBlobKey stretchEncryptionKey] to:data];
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
    [StringIO write:finderFileType to:data];
    [StringIO write:finderFileCreator to:data];
    [BooleanIO write:isFileExtensionHidden to:data];
    [IntegerIO writeInt32:st_dev to:data];
    [IntegerIO writeInt32:st_ino to:data];
    [IntegerIO writeUInt32:st_nlink to:data];
    [IntegerIO writeInt32:st_rdev to:data];
    [IntegerIO writeInt64:ctime_sec to:data];
    [IntegerIO writeInt64:ctime_nsec to:data];
    [IntegerIO writeInt64:createTime_sec to:data];
    [IntegerIO writeInt64:createTime_nsec to:data];
    [IntegerIO writeInt64:st_blocks to:data];
    [IntegerIO writeUInt32:st_blksize to:data];
}
- (uint64_t)sizeOnDisk {
    return (uint64_t)st_blocks * (uint64_t)512;
}

#pragma mark NSObject
- (BOOL)isEqual:(id)object {
    if (![object isKindOfClass:[Node class]]) {
        return NO;
    }
    Node *other = (Node *)object;
    return treeVersion == [other treeVersion] 
    && isTree == [other isTree]
    && uncompressedDataSize == [other uncompressedDataSize]
    && dataAreCompressed == [other dataAreCompressed]
    && [dataBlobKeys isEqualToArray:[other dataBlobKeys]]
    && [NSObject equalObjects:thumbnailBlobKey and:[other thumbnailBlobKey]]
    && [NSObject equalObjects:previewBlobKey and:[other previewBlobKey]]
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
    && [NSObject equalObjects:finderFileType and:[other finderFileType]]
    && [NSObject equalObjects:finderFileCreator and:[other finderFileCreator]]
    && st_dev == [other st_dev]
    && st_ino == [other st_ino]
    && st_nlink == [other st_nlink]
    && st_rdev == [other st_rdev]
    && ctime_sec == [other ctime_sec]
    && ctime_nsec == [other ctime_nsec]
    && createTime_sec == [other createTime_sec]
    && createTime_nsec == [other createTime_nsec]
    && st_blocks == [other st_blocks]
    && st_blksize == [other st_blksize];
}
- (NSUInteger)hash {
    return (NSUInteger)treeVersion + (dataAreCompressed ? 1 : 0) + [dataBlobKeys hash];
}
@end
