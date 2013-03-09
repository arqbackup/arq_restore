//
//  Tree.h
//  Backup
//
//  Created by Stefan Reitshamer on 3/25/09.
//  Copyright 2009 PhotoMinds LLC. All rights reserved.
//

#include <sys/stat.h>

#import "Blob.h"
@class BufferedInputStream;
@class Node;
@class BlobKey;

#define CURRENT_TREE_VERSION 18
#define TREE_HEADER_LENGTH (8)

@interface Tree : NSObject {
    int treeVersion;
    BOOL xattrsAreCompressed;
    BlobKey *xattrsBlobKey;
    unsigned long long xattrsSize;
    BOOL aclIsCompressed;
    BlobKey *aclBlobKey;
    int uid;
    int gid;
	int mode;
	long long mtime_sec;
	long long mtime_nsec;
	long long flags;
	int finderFlags;
	int extendedFinderFlags;
    int st_dev;
    int st_ino;
    uint32_t st_nlink; // in struct stat, it's only 16 bits.
    int st_rdev;
    int64_t ctime_sec;
    int64_t ctime_nsec;
    int64_t createTime_sec;
    int64_t createTime_nsec;
    int64_t st_blocks;
    uint32_t st_blksize;
    NSMutableDictionary *missingNodes;
	NSMutableDictionary *nodes;
}
+ (NSString *)errorDomain;
- (id)initWithBufferedInputStream:(BufferedInputStream *)is error:(NSError **)error;
- (NSArray *)childNodeNames;
- (Node *)childNodeWithName:(NSString *)name;
- (BOOL)containsNodeNamed:(NSString *)name;
- (NSDictionary *)nodes;
- (BOOL)containsMissingItems;
- (NSArray *)missingChildNodeNames;
- (Node *)missingChildNodeWithName:(NSString *)name;
- (NSDictionary *)missingNodes;
- (NSData *)toData;
- (BOOL)ctimeMatchesStat:(struct stat *)st;

@property(readonly) BOOL xattrsAreCompressed;
@property(readonly,copy) BlobKey *xattrsBlobKey;
@property(readonly) unsigned long long xattrsSize;
@property(readonly) BOOL aclIsCompressed;
@property(readonly,copy) BlobKey *aclBlobKey;
@property(readonly) int uid;
@property(readonly) int gid;
@property(readonly) int mode;
@property(readonly) long long mtime_sec;
@property(readonly) long long mtime_nsec;
@property(readonly) long long flags;
@property(readonly) int finderFlags;
@property(readonly) int extendedFinderFlags;
@property(readonly) int st_dev;
@property(readonly) int treeVersion;
@property(readonly) int st_rdev;
@property(readonly) long long ctime_sec;
@property(readonly) long long ctime_nsec;
@property(readonly) long long createTime_sec;
@property(readonly) long long createTime_nsec;
@property(readonly) uint32_t st_nlink;
@property(readonly) int st_ino;
@property(readonly) int64_t st_blocks;
@property(readonly) uint32_t st_blksize;
@property(readonly) uint64_t aggregateUncompressedDataSize;
@end
