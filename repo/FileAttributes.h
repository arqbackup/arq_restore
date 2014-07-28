//
//  FileAttributes.h
//  Backup
//
//  Created by Stefan Reitshamer on 4/22/09.
//  Copyright 2009 PhotoMinds LLC. All rights reserved.
//

#include <sys/stat.h>



OSStatus SymlinkPathMakeRef(const UInt8 *path, FSRef *ref, Boolean *isDirectory);

@interface FileAttributes : NSObject {
    BOOL targetExists;
    struct timespec createTime;
    int finderFlags;
    int extendedFinderFlags;
    NSString *finderFileType;
    NSString *finderFileCreator;
    BOOL isFileExtensionHidden;
}
+ (NSString *)errorDomain;

- (id)initWithPath:(NSString *)thePath stat:(struct stat *)theStat error:(NSError **)error;

- (int)finderFlags;
- (int)extendedFinderFlags;
- (NSString *)finderFileType;
- (NSString *)finderFileCreator;
- (int64_t)createTime_sec;
- (int64_t)createTime_nsec;
- (BOOL)isFileExtensionHidden;

+ (BOOL)applyFinderFileType:(NSString *)fft finderFileCreator:(NSString *)ffc to:(FSRef *)fsRef error:(NSError **)error;
+ (BOOL)applyFlags:(unsigned long)flags toPath:(NSString *)thePath error:(NSError **)error;
+ (BOOL)applyFinderFlags:(int)ff to:(FSRef *)fsRef isDirectory:(BOOL)isDirectory error:(NSError **)error;
+ (BOOL)applyExtendedFinderFlags:(int)eff to:(FSRef *)fsRef isDirectory:(BOOL)isDirectory error:(NSError **)error;
+ (BOOL)applyFileExtensionHidden:(BOOL)hidden toPath:(NSString *)thePath error:(NSError **)error;
+ (BOOL)applyUID:(int)uid gid:(int)gid toPath:(NSString *)thePath error:(NSError **)error;
+ (BOOL)applyMode:(int)mode toPath:(NSString *)thePath isDirectory:(BOOL)isDirectory error:(NSError **)error;
+ (BOOL)applyMTimeSec:(int64_t)mtime_sec mTimeNSec:(int64_t)mtime_nsec toPath:(NSString *)thePath error:(NSError **)error;
+ (BOOL)applyCreateTimeSec:(int64_t)theCreateTime_sec createTimeNSec:(int64_t)theCreateTime_nsec to:(FSRef *)fsRef error:(NSError **)error;
@end
