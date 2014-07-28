//
//  Node.h
//  s3print
//
//  Created by Stefan Reitshamer on 4/10/09.
//  Copyright 2009 PhotoMinds LLC. All rights reserved.
//

#include <sys/stat.h>

@protocol InputStream;
@class BlobKey;
@class BufferedInputStream;


@interface Node : NSObject {
    int treeVersion;
	BOOL isTree;
    BOOL treeContainsMissingItems;
    unsigned long long uncompressedDataSize;
    NSMutableArray *dataBlobKeys;
    BlobKey *xattrsBlobKey;
    unsigned long long xattrsSize;
    BlobKey *aclBlobKey;
    int uid;
    int gid;
	int mode;
	int64_t mtime_sec;
    int64_t mtime_nsec;
	long long flags;
	int finderFlags;
	int extendedFinderFlags;
	NSString *finderFileType;
	NSString *finderFileCreator;
	BOOL isFileExtensionHidden;
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
}
- (id)initWithInputStream:(BufferedInputStream *)is treeVersion:(int)theTreeVersion error:(NSError **)error;
- (void)writeToData:(NSMutableData *)data;
- (BOOL)dataMatchesStat:(struct stat *)st;
- (BOOL)ctimeMatchesStat:(struct stat *)st;

@property(readonly) BOOL isTree;
@property(readonly) BOOL treeContainsMissingItems;
@property(readonly,copy) BlobKey *treeBlobKey;
@property(readonly,copy) NSArray *dataBlobKeys;

@property(readonly) unsigned long long uncompressedDataSize;
@property(readonly,copy) BlobKey *xattrsBlobKey;
@property(readonly) unsigned long long xattrsSize;
@property(readonly,copy) BlobKey *aclBlobKey;
@property(readonly) int uid;
@property(readonly) int gid;
@property(readonly) int mode;
@property(readonly) long long mtime_sec;
@property(readonly) long long mtime_nsec;
@property(readonly) long long flags;
@property(readonly) int finderFlags;
@property(readonly) int extendedFinderFlags;
@property(readonly,copy) NSString *finderFileType;
@property(readonly,copy) NSString *finderFileCreator;
@property(readonly) BOOL isFileExtensionHidden;
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
@end
