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

#include <CoreServices/CoreServices.h>
#include <sys/attr.h>
#include <unistd.h>
#include <sys/time.h>
#include <stdio.h>
#import "FileAttributes.h"
#import "SHA1Hash.h"
#import "FileACL.h"
#import "SetNSError.h"
#import "OSStatusDescription.h"

#define kCouldNotCreateCFString	4
#define kCouldNotGetStringData	5
#define MAX_PATH				1024

struct createDateBuf {
    u_int32_t length;
    struct timespec createTime;
};

static OSStatus ConvertCStringToHFSUniStr(const char* cStr, HFSUniStr255 *uniStr) {
	OSStatus oss = noErr;
	CFStringRef tmpStringRef = CFStringCreateWithCString(kCFAllocatorDefault, cStr, kCFStringEncodingMacRoman);
	if (tmpStringRef != NULL) {
		if (CFStringGetCString(tmpStringRef, (char*)uniStr->unicode, sizeof(uniStr->unicode), kCFStringEncodingUnicode)) {
			uniStr->length = CFStringGetLength(tmpStringRef);
        } else {
			oss = kCouldNotGetStringData;
        }
		CFRelease(tmpStringRef);
	} else {
		oss = kCouldNotCreateCFString;
    }
	return oss;
}
static OSStatus SymlinkPathMakeRef(const UInt8 *path, FSRef *ref, Boolean *isDirectory) {
    FSRef tmpFSRef;
    char tmpPath[MAX_PATH];
    char *tmpNamePtr;
    OSStatus oss;
    
    strcpy(tmpPath, (char *)path);
    tmpNamePtr = strrchr(tmpPath, '/');
    if (*(tmpNamePtr + 1) == '\0') {
        // Last character in the path is a '/'.
        *tmpNamePtr = '\0';
        tmpNamePtr = strrchr(tmpPath, '/');
    }
    *tmpNamePtr = '\0';
    tmpNamePtr++;
    
    // Get FSRef for parent directory.
    oss = FSPathMakeRef((const UInt8 *)tmpPath, &tmpFSRef, NULL);
    if (oss == noErr) {
        HFSUniStr255 uniName;
        oss = ConvertCStringToHFSUniStr(tmpNamePtr, &uniName);
        if (oss == noErr) {
            FSRef newFSRef;
            oss = FSMakeFSRefUnicode(&tmpFSRef, uniName.length, uniName.unicode, kTextEncodingUnknown, &newFSRef);
            tmpFSRef = newFSRef;
        }
    }
    if (oss == noErr) {
        *ref = tmpFSRef;
    }
    return oss;
}

@implementation FileAttributes
- (id)initWithPath:(NSString *)thePath error:(NSError **)error {
    struct stat theStat;
    int ret = lstat([thePath fileSystemRepresentation], &theStat);
    if (ret == -1) {
        SETNSERROR(@"UnixErrorDomain", errno, @"%s", strerror(errno));
        return nil;
    }
    return [self initWithPath:thePath stat:&theStat error:error];
}
- (id)initWithPath:(NSString *)thePath stat:(struct stat *)theStat error:(NSError **)error {
    if (self = [super init]) {
        path = [thePath copy];
        cPath = [path fileSystemRepresentation];
        memcpy(&st, theStat, sizeof(st));
        targetExists = YES;
        if (S_ISLNK(st.st_mode)) {
            struct stat targetSt;
            int ret = stat(cPath, &targetSt);
            if (ret == -1 && errno == ENOENT) {
                targetExists = NO;
            }
        }
        if (targetExists) {
            FSRef fsRef;
            Boolean isDirectory;
            OSStatus oss = 0;
            if (S_ISLNK(st.st_mode)) {
                oss = SymlinkPathMakeRef((UInt8*)cPath, &fsRef, &isDirectory);
            } else {
                oss = FSPathMakeRef((UInt8*)cPath, &fsRef, &isDirectory);
            }
            if (oss == bdNamErr) {
                HSLogInfo(@"skipping finder flags for %s: %@", cPath, [OSStatusDescription descriptionForMacOSStatus:oss]);
            }else if (oss != noErr) {
                SETNSERROR(@"MacFilesErrorDomain", oss, @"%@", [OSStatusDescription descriptionForMacOSStatus:oss]);
                [self release];
                self = nil;
                return self;
            } else {
                FSCatalogInfo catalogInfo;
                OSErr oserr = FSGetCatalogInfo(&fsRef, kFSCatInfoCreateDate | kFSCatInfoFinderInfo | kFSCatInfoFinderXInfo, &catalogInfo, NULL, NULL, NULL);
                if (oserr) {
                    SETNSERROR(@"MacFilesErrorDomain", oss, @"%@", [OSStatusDescription descriptionForMacOSStatus:(OSStatus)oserr]);
                    [self release];
                    self = nil;
                    return self;
                }
                finderFlags = 0;
                extendedFinderFlags = 0;
                if (isDirectory) {
                    FolderInfo *folderInfo = (FolderInfo *)&catalogInfo.finderInfo;
                    finderFlags = folderInfo->finderFlags;
                    ExtendedFolderInfo *extFolderInfo = (ExtendedFolderInfo *)&catalogInfo.extFinderInfo;
                    extendedFinderFlags = extFolderInfo->extendedFinderFlags;
                    finderFileType = [[NSString alloc] initWithString:@""];
                    finderFileCreator = [[NSString alloc] initWithString:@""];
                } else {
                    FileInfo *fileInfo = (FileInfo *)&catalogInfo.finderInfo;
                    finderFlags = fileInfo->finderFlags;
                    ExtendedFileInfo *extFileInfo = (ExtendedFileInfo *)&catalogInfo.extFinderInfo;
                    extendedFinderFlags = extFileInfo->extendedFinderFlags;
                    
                    char fileType[5];
                    fileType[0] = *((const char *)&fileInfo->fileType + 3);
                    fileType[1] = *((const char *)&fileInfo->fileType + 2);
                    fileType[2] = *((const char *)&fileInfo->fileType + 1);
                    fileType[3] = *((const char *)&fileInfo->fileType);
                    fileType[4] = 0;
                    finderFileType = [[NSString alloc] initWithCString:fileType encoding:NSUTF8StringEncoding];
                    char fileCreator[5];
                    fileCreator[0] = *((const char *)&fileInfo->fileCreator + 3);
                    fileCreator[1] = *((const char *)&fileInfo->fileCreator + 2);
                    fileCreator[2] = *((const char *)&fileInfo->fileCreator + 1);
                    fileCreator[3] = *((const char *)&fileInfo->fileCreator);
                    fileCreator[4] = 0;
                    finderFileCreator = [[NSString alloc] initWithCString:fileCreator encoding:NSUTF8StringEncoding];
                }
            }
        }
        
        if (![FileACL aclText:&aclString forFile:path error:error]) {
            [self release];
            self = nil;
            return self;
        }
        [aclString retain];
        
        struct attrlist attrList;
        memset(&attrList, 0, sizeof(attrList));
        attrList.bitmapcount = ATTR_BIT_MAP_COUNT;
        attrList.commonattr = ATTR_CMN_CRTIME;
        struct createDateBuf createDateBuf;
        if (getattrlist(cPath, &attrList, &createDateBuf, sizeof(createDateBuf), FSOPT_NOFOLLOW) == -1) {
            SETNSERROR(@"UnixErrorDomain", errno, @"Error getting create date for %@: %s", thePath, strerror(errno));
            [self release];
            self = nil;
            return self;
        }
        createTime.tv_sec = createDateBuf.createTime.tv_sec;
        createTime.tv_nsec = createDateBuf.createTime.tv_nsec;
    }
    return self;
}
- (void)dealloc {
    [path release];
    [aclString release];
    [finderFileType release];
    [finderFileCreator release];
    [super dealloc];
}
- (unsigned long long)fileSize {
    return (unsigned long long)st.st_size;
}
- (NSString *)aclString {
    return aclString;
}
- (NSString *)aclSHA1 {
    NSString *sha1 = nil;
    if (aclString) {
        sha1 = [SHA1Hash hashData:[aclString dataUsingEncoding:NSUTF8StringEncoding]];
    }
    return sha1;
}
- (int)uid {
    return st.st_uid;
}
- (int)gid {
    return st.st_gid;
}
- (int)mode {
    return st.st_mode;
}
- (long)mtime_sec {
    return st.st_mtimespec.tv_sec;
}
- (long)mtime_nsec {
    return st.st_mtimespec.tv_nsec;
}
- (long)flags {
    return st.st_flags;
}

- (int)finderFlags {
    return finderFlags;
}
- (int)extendedFinderFlags {
    return extendedFinderFlags;
}
- (NSString *)finderFileType {
    return finderFileType;
}
- (NSString *)finderFileCreator {
    return finderFileCreator;
}
- (BOOL)isExtensionHidden {
    return st.st_flags & UF_HIDDEN;
}
- (BOOL)isFifo {
    return S_ISFIFO(st.st_mode);
}
- (BOOL)isDevice {
    return S_ISBLK(st.st_mode) || S_ISCHR(st.st_mode);
}
- (BOOL)isSymbolicLink {
    return S_ISLNK(st.st_mode);
}
- (BOOL)isRegularFile {
    return S_ISREG(st.st_mode);
}
- (BOOL)isSocket {
    return S_ISSOCK(st.st_mode);
}
- (int)st_dev {
    return st.st_dev;
}
- (int)st_ino {
    return st.st_ino;
}
- (uint32_t)st_nlink {
    return st.st_nlink;
}
- (int)st_rdev {
    return st.st_rdev;
}
- (int64_t)ctime_sec {
    return st.st_ctimespec.tv_sec;
}
- (int64_t)ctime_nsec {
    return st.st_ctimespec.tv_nsec;
}
- (int64_t)createTime_sec {
    return createTime.tv_sec;
}
- (int64_t)createTime_nsec {
    return createTime.tv_nsec;
}
- (int64_t)st_blocks {
    return st.st_blocks;
}
- (uint32_t)st_blksize {
    return st.st_blksize;
}
- (BOOL)applyFinderFileType:(NSString *)fft finderFileCreator:(NSString *)ffc error:(NSError **)error {
    if (targetExists && (![fft isEqualToString:finderFileType] || ![ffc isEqualToString:finderFileCreator])) {
        if ([fft length] != 4) {
            HSLogWarn(@"not applying finder file type '%@' to %@: invalid length (must be 4 characters)", fft, path);
        } else if ([ffc length] != 4) {
            HSLogWarn(@"not applying finder file type '%@' to %@: invalid length (must be 4 characters)", ffc, path);
        } else {
            FSRef fsRef;
            Boolean isDirectory;
            OSStatus oss = 0;
            if (S_ISLNK(st.st_mode)) {
                oss = SymlinkPathMakeRef((UInt8*)cPath, &fsRef, &isDirectory);
            } else {
                oss = FSPathMakeRef((UInt8*)cPath, &fsRef, &isDirectory);
            }
            if (oss != noErr) {
                if (oss == bdNamErr) {
                    HSLogInfo(@"not setting finder file type/creator on %s: bad name", cPath);
                    return YES;
                } else {
                    SETNSERROR(@"FileManagerErrorDomain", -1, @"%@", [OSStatusDescription descriptionForMacOSStatus:oss]);
                    return NO;
                }
            }
            if (isDirectory) {
                SETNSERROR(@"FileManagerErrorDomain", -1, @"cannot apply finderFileType to a directory");
                return NO;
            }
            
            FSCatalogInfo catalogInfo;
            OSErr oserr = FSGetCatalogInfo(&fsRef, kFSCatInfoFinderInfo, &catalogInfo, NULL, NULL, NULL);
            if (oserr) {
                SETNSERROR(@"FileManagerErrorDomain", -1, @"%@", [OSStatusDescription descriptionForMacOSStatus:(OSStatus)oserr]);
                return NO;
            }
            FileInfo *fileInfo = (FileInfo *)&catalogInfo.finderInfo;
            const char *fileType = [fft UTF8String];
            char *destFileType = (char *)&fileInfo->fileType;
            destFileType[3] = fileType[0];
            destFileType[2] = fileType[1];
            destFileType[1] = fileType[2];
            destFileType[0] = fileType[3];
            
            const char *fileCreator = [ffc UTF8String];
            char *destFileCreator = (char *)&fileInfo->fileCreator;
            destFileCreator[3] = fileCreator[0];
            destFileCreator[2] = fileCreator[1];
            destFileCreator[1] = fileCreator[2];
            destFileCreator[0] = fileCreator[3];
            
            oserr = FSSetCatalogInfo(&fsRef, kFSCatInfoFinderInfo, &catalogInfo);
            if (oserr) {
                SETNSERROR(@"FileManagerErrorDomain", -1, @"%@", [OSStatusDescription descriptionForMacOSStatus:(OSStatus)oserr]);
                return NO;
            }
            [finderFileType release];
            finderFileType = [fft copy];
            [finderFileCreator release];
            finderFileCreator = [ffc copy];
        }
    }
    return YES;
}
- (BOOL)applyFlags:(int)flags error:(NSError **)error {
    if (targetExists && flags != st.st_flags) {
        HSLogTrace(@"chflags(%s, %d)", cPath, flags);
        if (chflags(cPath, flags) == -1) {
            SETNSERROR(@"UnixErrorDomain", errno, @"chflags: %s", strerror(errno));
            return NO;
        }
        st.st_flags = flags;
    }
    return YES;
}
- (BOOL)applyAcl:(NSString *)theACLString error:(NSError **)error {
    BOOL ret = YES;
    if (![theACLString isEqualToString:aclString]) {
        ret = [FileACL writeACLText:theACLString toFile:path error:error];
        if (ret) {
            [aclString release];
            aclString = [theACLString retain];
        }
    }
    return ret;
}
- (BOOL)applyFinderFlags:(int)ff error:(NSError **)error {
    if (targetExists && ff != finderFlags) {
        FSRef fsRef;
        Boolean isDirectory;
        OSStatus oss = 0;
        if (S_ISLNK(st.st_mode)) {
            oss = SymlinkPathMakeRef((UInt8*)cPath, &fsRef, &isDirectory);
        } else {
            oss = FSPathMakeRef((UInt8*)cPath, &fsRef, &isDirectory);
        }
        if (oss != noErr) {
            if (oss == bdNamErr) {
                HSLogInfo(@"not setting finder file type/creator on %s: bad name", cPath);
                return YES;
            } else {
                SETNSERROR(@"FileManagerErrorDomain", -1, @"%@", [OSStatusDescription descriptionForMacOSStatus:oss]);
                return NO;
            }
        }
        FSCatalogInfo catalogInfo;
        OSErr oserr = FSGetCatalogInfo(&fsRef, kFSCatInfoFinderInfo, &catalogInfo, NULL, NULL, NULL);
        if (oserr) {
            SETNSERROR(@"FileManagerErrorDomain", -1, @"%@", [OSStatusDescription descriptionForMacOSStatus:(OSStatus)oserr]);
            return NO;
        }
        if (isDirectory) {
            FolderInfo *folderInfo = (FolderInfo *)&catalogInfo.finderInfo;
            folderInfo->finderFlags = ff;
        } else {
            FileInfo *fileInfo = (FileInfo *)&catalogInfo.finderInfo;
            fileInfo->finderFlags = ff;
        }
        oserr = FSSetCatalogInfo(&fsRef, kFSCatInfoFinderInfo, &catalogInfo);
        if (oserr) {
            SETNSERROR(@"FileManagerErrorDomain", -1, @"%@", [OSStatusDescription descriptionForMacOSStatus:(OSStatus)oserr]);
            return NO;
        }
        finderFlags = ff;
    }
    return YES;
}
- (BOOL)applyExtendedFinderFlags:(int)eff error:(NSError **)error {
    if (targetExists && extendedFinderFlags != eff) {
        FSRef fsRef;
        Boolean isDirectory;
        OSStatus oss = 0;
        if (S_ISLNK(st.st_mode)) {
            oss = SymlinkPathMakeRef((UInt8*)cPath, &fsRef, &isDirectory);
        } else {
            oss = FSPathMakeRef((UInt8*)cPath, &fsRef, &isDirectory);
        }
        if (oss != noErr) {
            if (oss == bdNamErr) {
                HSLogInfo(@"not setting finder file type/creator on %s: bad name", cPath);
                return YES;
            } else {
                SETNSERROR(@"FileManagerErrorDomain", -1, @"%@", [OSStatusDescription descriptionForMacOSStatus:oss]);
                return NO;
            }
        }
        FSCatalogInfo catalogInfo;
        OSErr oserr = FSGetCatalogInfo(&fsRef, kFSCatInfoFinderXInfo, &catalogInfo, NULL, NULL, NULL);
        if (oserr) {
            SETNSERROR(@"FileManagerErrorDomain", -1, @"%@", [OSStatusDescription descriptionForMacOSStatus:(OSStatus)oserr]);
            return NO;
        }
        if (isDirectory) {
            ExtendedFolderInfo *extFolderInfo = (ExtendedFolderInfo *)&catalogInfo.extFinderInfo;
            extFolderInfo->extendedFinderFlags = eff;
        } else {
            ExtendedFileInfo *extFileInfo = (ExtendedFileInfo *)&catalogInfo.extFinderInfo;
            extFileInfo->extendedFinderFlags = eff;
        }
        oserr = FSSetCatalogInfo(&fsRef, kFSCatInfoFinderXInfo, &catalogInfo);
        if (oserr) {
            SETNSERROR(@"FileManagerErrorDomain", -1, @"%@", [OSStatusDescription descriptionForMacOSStatus:(OSStatus)oserr]);
            return NO;
        }
        extendedFinderFlags = eff;
    }
    return YES;
}
- (BOOL)applyExtensionHidden:(BOOL)hidden error:(NSError **)error {
    BOOL ret = YES;
    if (hidden != [self isExtensionHidden]) {
        NSDictionary *attribs = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:hidden], NSFileExtensionHidden, nil];
        ret = [[NSFileManager defaultManager] setAttributes:attribs ofItemAtPath:path error:error];
        if (ret) {
            if (hidden) {
                st.st_flags = st.st_flags & UF_HIDDEN;
            } else {
                st.st_flags = st.st_flags & (0xffffffff ^ UF_HIDDEN);
            }
        }
    }
    return ret;
}
- (BOOL)applyUID:(int)uid gid:(int)gid error:(NSError **)error {
    if (uid != st.st_uid || gid != st.st_gid) {
        if (lchown(cPath, uid, gid) == -1) {
            HSLogError(@"lchown failed");
            SETNSERROR(@"UnixErrorDomain", errno, @"lchown: %s", strerror(errno));
            return NO;
        }
        HSLogDebug(@"lchown(%s, %d, %d); euid=%d", cPath, uid, gid, geteuid());
        st.st_uid = uid;
        st.st_gid = gid;
    }
    return YES;
}
- (BOOL)applyMode:(int)mode error:(NSError **)error {
    if (mode != st.st_mode) {
        if (S_ISDIR(st.st_mode)) {
            int ret = chmod(cPath, mode);
            if (ret == -1) {
                SETNSERROR(@"UnixErrorDomain", errno, @"Setting permissions on %@: %s", path, strerror(errno));
                return NO;
            }
            HSLogDebug(@"chmod(%s, 0%6o)", cPath, mode);
        } else {
            int fd = open(cPath, O_RDWR|O_SYMLINK);
            if (fd == -1) {
                SETNSERROR(@"UnixErrorDomain", errno, @"%s", strerror(errno));
                return NO;
            }
            int ret = fchmod(fd, mode);
            close(fd);
            if (ret == -1) {
                SETNSERROR(@"UnixErrorDomain", errno, @"Setting permissions on %@: %s", path, strerror(errno));
                return NO;
            }
            HSLogDebug(@"fchmod(%s, 0%6o)", cPath, mode);
        }
        st.st_mode = mode;
    }
    return YES;
}
- (BOOL)applyMTimeSec:(int64_t)mtime_sec mTimeNSec:(int64_t)mtime_nsec error:(NSError **)error {
    if (st.st_mtimespec.tv_sec != mtime_sec
        || st.st_mtimespec.tv_nsec != mtime_nsec) {
        struct timespec mtimeSpec = { mtime_sec, mtime_nsec };
        struct timeval atimeVal;
        struct timeval mtimeVal;
        TIMESPEC_TO_TIMEVAL(&atimeVal, &mtimeSpec); // Just use mtime because we don't have atime, nor do we care about atime.
        TIMESPEC_TO_TIMEVAL(&mtimeVal, &mtimeSpec);
        struct timeval timevals[2];
        timevals[0] = atimeVal;
        timevals[1] = mtimeVal;
        if (utimes(cPath, timevals) == -1) {
            SETNSERROR(@"UnixErrorDomain", errno, @"utimes(%@): %s", path, strerror(errno));
            return NO;
        }
    }
    return YES;
}
- (BOOL)applyCreateTimeSec:(int64_t)theCreateTime_sec createTimeNSec:(int64_t)theCreateTime_nsec error:(NSError **)error {
    if (createTime.tv_sec != theCreateTime_sec || createTime.tv_nsec != theCreateTime_nsec) {
        createTime.tv_sec = theCreateTime_sec;
        createTime.tv_nsec = theCreateTime_nsec;
        
        struct attrlist attrList;
        memset(&attrList, 0, sizeof(attrList));
        attrList.bitmapcount = ATTR_BIT_MAP_COUNT;
        attrList.commonattr = ATTR_CMN_CRTIME;
        if (setattrlist(cPath, &attrList, &createTime, sizeof(createTime), FSOPT_NOFOLLOW) == -1) {
            SETNSERROR(@"UnixErrorDomain", errno, @"Error setting create date on %@: %s", path, strerror(errno));
            return NO;
        }
    }
    return YES;
}
@end
