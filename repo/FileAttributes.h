/*
 Copyright (c) 2009-2014, Stefan Reitshamer http://www.haystacksoftware.com
 
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
