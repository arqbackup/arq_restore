//
//  FileAttributes.h
//  Backup
//
//  Created by Stefan Reitshamer on 4/22/09.
//  Copyright 2009 PhotoMinds LLC. All rights reserved.
//

#include <sys/stat.h>


@interface FileAttributes : NSObject {
    BOOL targetExists;
    NSString *path;
    const char *cPath;
    struct stat st;
    struct timespec createTime;
    int finderFlags;
    int extendedFinderFlags;
    NSString *finderFileType;
    NSString *finderFileCreator;
}
- (id)initWithPath:(NSString *)thePath error:(NSError **)error;
- (id)initWithPath:(NSString *)thePath stat:(struct stat *)st error:(NSError **)error;

- (unsigned long long)fileSize;
- (int)uid;
- (int)gid;
- (int)mode;
- (long)mtime_sec;
- (long)mtime_nsec;
- (long)flags;
- (int)finderFlags;
- (int)extendedFinderFlags;
- (NSString *)finderFileType;
- (NSString *)finderFileCreator;
- (BOOL)isExtensionHidden;
- (BOOL)isFifo;
- (BOOL)isDevice;
- (BOOL)isSymbolicLink;
- (BOOL)isRegularFile;
- (BOOL)isSocket;
- (int)st_dev;
- (int)st_ino;
- (uint32_t)st_nlink;
- (int)st_rdev;
- (int64_t)ctime_sec;
- (int64_t)ctime_nsec;
- (int64_t)createTime_sec;
- (int64_t)createTime_nsec;
- (int64_t)st_blocks;
- (uint32_t)st_blksize;

- (BOOL)applyFinderFileType:(NSString *)finderFileType finderFileCreator:(NSString *)finderFileCreator error:(NSError **)error;
- (BOOL)applyFlags:(int)flags error:(NSError **)error;
- (BOOL)applyFinderFlags:(int)finderFlags error:(NSError **)error;
- (BOOL)applyExtendedFinderFlags:(int)extendedFinderFlags error:(NSError **)error;
- (BOOL)applyExtensionHidden:(BOOL)isExtensionHidden error:(NSError **)error;
- (BOOL)applyUID:(int)uid gid:(int)gid error:(NSError **)error;
- (BOOL)applyMode:(int)mode error:(NSError **)error;
- (BOOL)applyMTimeSec:(int64_t)mtime_sec mTimeNSec:(int64_t)mtime_nsec error:(NSError **)error;
- (BOOL)applyCreateTimeSec:(int64_t)createTime_sec createTimeNSec:(int64_t)createTime_sec error:(NSError **)error;
@end
