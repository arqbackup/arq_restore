/*
 Copyright (c) 2009, Stefan Reitshamer http://www.haystacksoftware.com
 
 All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 
 * Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in the
 documentation and/or other materials provided with the distribution.
 
 * Neither the names of PhotoMinds LLC or Haystack Software, nor the names of 
 their contributors may be used to endorse or promote products derived from
 this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
 TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */ 

#include <sys/stat.h>
#import <Cocoa/Cocoa.h>

@interface FileAttributes : NSObject {
    BOOL targetExists;
    NSString *path;
    const char *cPath;
    struct stat st;
    struct timespec createTime;
    NSString *aclString;
    int finderFlags;
    int extendedFinderFlags;
    NSString *finderFileType;
    NSString *finderFileCreator;
}
- (id)initWithPath:(NSString *)thePath error:(NSError **)error;
- (id)initWithPath:(NSString *)thePath stat:(struct stat *)st error:(NSError **)error;

- (unsigned long long)fileSize;
- (NSString *)aclString;
- (NSString *)aclSHA1;
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
- (BOOL)applyAcl:(NSString *)aclString error:(NSError **)error;
- (BOOL)applyFinderFlags:(int)finderFlags error:(NSError **)error;
- (BOOL)applyExtendedFinderFlags:(int)extendedFinderFlags error:(NSError **)error;
- (BOOL)applyExtensionHidden:(BOOL)isExtensionHidden error:(NSError **)error;
- (BOOL)applyUID:(int)uid gid:(int)gid error:(NSError **)error;
- (BOOL)applyMode:(int)mode error:(NSError **)error;
- (BOOL)applyMTimeSec:(int64_t)mtime_sec mTimeNSec:(int64_t)mtime_nsec error:(NSError **)error;
- (BOOL)applyCreateTimeSec:(int64_t)createTime_sec createTimeNSec:(int64_t)createTime_sec error:(NSError **)error;
@end
