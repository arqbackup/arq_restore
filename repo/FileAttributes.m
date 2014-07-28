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


#include <CoreServices/CoreServices.h>
#include <sys/attr.h>
#include <unistd.h>
#include <sys/time.h>
#include <stdio.h>
#import "FileAttributes.h"
#import "SHA1Hash.h"
#import "FileACL.h"

#import "OSStatusDescription.h"
#import "NSError_extra.h"

#define kCouldNotCreateCFString	4
#define kCouldNotGetStringData	5
#define MAX_PATH				1024

struct createDateBuf {
    u_int32_t length;
    struct timespec createTime;
};

static OSStatus ConvertCStringToHFSUniStr(const char* cStr, HFSUniStr255 *uniStr) {
	OSStatus oss = noErr;
	CFStringRef tmpStringRef = CFStringCreateWithCString(kCFAllocatorDefault, cStr, kCFStringEncodingUTF8);
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
OSStatus SymlinkPathMakeRef(const UInt8 *path, FSRef *ref, Boolean *isDirectory) {
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
+ (NSString *)errorDomain {
    return @"FileAttributesErrorDomain";
}
- (id)initWithPath:(NSString *)thePath stat:(struct stat *)theStat error:(NSError **)error {
    if (self = [super init]) {
        NSError *myError = nil;
        NSDictionary *attribs = [[NSFileManager defaultManager] attributesOfItemAtPath:thePath error:&myError];
        if (attribs == nil) {
            myError = [[[NSError alloc] initWithDomain:[FileAttributes errorDomain]
                                                  code:-1
                                              userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                                        [NSString stringWithFormat:@"[FileAttributes attributesOfItemAtPath:%@]: %@", thePath, [myError localizedDescription]], NSLocalizedDescriptionKey,
                                                        myError, NSUnderlyingErrorKey,
                                                        nil]] autorelease];
            HSLogError(@"%@", myError);
            SETERRORFROMMYERROR;
            [self release];
            return nil;
        }
        isFileExtensionHidden = [[attribs objectForKey:NSFileExtensionHidden] boolValue];
        
        targetExists = YES;
        if (S_ISLNK(theStat->st_mode)) {
            struct stat targetSt;
            int ret = stat([thePath fileSystemRepresentation], &targetSt);
            if (ret == -1 && errno == ENOENT) {
                targetExists = NO;
            }
        }
        if (targetExists) {
            FSRef fsRef;
            Boolean isDirectory = false;
            OSStatus oss = 0;
            if (S_ISLNK(theStat->st_mode)) {
                oss = SymlinkPathMakeRef((UInt8*)[thePath fileSystemRepresentation], &fsRef, &isDirectory);
            } else {
                oss = FSPathMakeRef((UInt8*)[thePath fileSystemRepresentation], &fsRef, &isDirectory);
            }
            if (oss == bdNamErr) {
                HSLogInfo(@"skipping finder flags for %@: %@", thePath, [OSStatusDescription descriptionForOSStatus:oss]);
            } else if (oss == ioErr) {
                HSLogInfo(@"skipping finder flags for %@: %@", thePath, [OSStatusDescription descriptionForOSStatus:oss]);
            } else if (oss != noErr) {
                HSLogError(@"error making FSRef for %@: %@", thePath, [OSStatusDescription descriptionForOSStatus:oss]);
                SETNSERROR([FileAttributes errorDomain], oss, @"error making FSRef for %@: %@", thePath, [OSStatusDescription descriptionForOSStatus:oss]);
                [self release];
                self = nil;
                return self;
            } else {
                FSCatalogInfo catalogInfo;
                OSErr oserr = FSGetCatalogInfo(&fsRef, kFSCatInfoCreateDate | kFSCatInfoFinderInfo | kFSCatInfoFinderXInfo, &catalogInfo, NULL, NULL, NULL);
                if (oserr) {
                    HSLogError(@"FSGetCatalogInfo(%@): %@", thePath, [OSStatusDescription descriptionForOSStatus:(OSStatus)oserr]);
                    SETNSERROR([FileAttributes errorDomain], oss, @"FSGetCatalogInfo(%@): %@", thePath, [OSStatusDescription descriptionForOSStatus:(OSStatus)oserr]);
                    [self release];
                    self = nil;
                    return self;
                }
                
                CFTimeInterval theCreateTime; // double: seconds since reference date
                if (UCConvertUTCDateTimeToCFAbsoluteTime(&catalogInfo.createDate, &theCreateTime) != noErr) {
                    HSLogError(@"error converting create time to CFAbsoluteTime");
                } else {
                    createTime.tv_sec = (__darwin_time_t)(theCreateTime + NSTimeIntervalSince1970);
                    CFTimeInterval subsecond = theCreateTime - (double)((int64_t)theCreateTime);
                    createTime.tv_nsec = (__darwin_time_t)(subsecond * 1000000000.0);
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
    }
    return self;
}
- (void)dealloc {
    [finderFileType release];
    [finderFileCreator release];
    [super dealloc];
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
- (int64_t)createTime_sec {
    return createTime.tv_sec;
}
- (int64_t)createTime_nsec {
    return createTime.tv_nsec;
}
- (BOOL)isFileExtensionHidden {
    return isFileExtensionHidden;
}

+ (BOOL)applyFinderFileType:(NSString *)fft finderFileCreator:(NSString *)ffc to:(FSRef *)fsRef error:(NSError **)error {
    if ([fft length] != 4) {
        HSLogTrace(@"not applying finder file type '%@': invalid length (must be 4 characters)", fft);
    } else if ([ffc length] != 4) {
        HSLogTrace(@"not applying finder file type '%@': invalid length (must be 4 characters)", ffc);
    } else {
        FSCatalogInfo catalogInfo;
        OSErr oserr = FSGetCatalogInfo(fsRef, kFSCatInfoFinderInfo, &catalogInfo, NULL, NULL, NULL);
        if (oserr) {
            SETNSERROR(@"FileManagerErrorDomain", -1, @"%@", [OSStatusDescription descriptionForOSStatus:(OSStatus)oserr]);
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
        
        oserr = FSSetCatalogInfo(fsRef, kFSCatInfoFinderInfo, &catalogInfo);
        if (oserr) {
            SETNSERROR(@"FileManagerErrorDomain", -1, @"%@", [OSStatusDescription descriptionForOSStatus:(OSStatus)oserr]);
            return NO;
        }
    }
    return YES;
}
+ (BOOL)applyFlags:(unsigned long)flags toPath:(NSString *)thePath error:(NSError **)error {
    HSLogTrace(@"chflags(%@, %ld)", thePath, flags);
    if (chflags([thePath fileSystemRepresentation], (unsigned int)flags) == -1) {
        int errnum = errno;
        HSLogError(@"chflags(%@, %ld) error %d: %s", thePath, flags, errnum, strerror(errnum));
        SETNSERROR(@"UnixErrorDomain", errnum, @"error changing flags of %@: %s", thePath, strerror(errnum));
        return NO;
    }
    return YES;
}
+ (BOOL)applyFinderFlags:(int)ff to:(FSRef *)fsRef isDirectory:(BOOL)isDirectory error:(NSError **)error {
    FSCatalogInfo catalogInfo;
    OSErr oserr = FSGetCatalogInfo(fsRef, kFSCatInfoFinderInfo, &catalogInfo, NULL, NULL, NULL);
    if (oserr) {
        SETNSERROR(@"FileManagerErrorDomain", -1, @"%@", [OSStatusDescription descriptionForOSStatus:(OSStatus)oserr]);
        return NO;
    }
    if (isDirectory) {
        FolderInfo *folderInfo = (FolderInfo *)&catalogInfo.finderInfo;
        folderInfo->finderFlags = ff;
    } else {
        FileInfo *fileInfo = (FileInfo *)&catalogInfo.finderInfo;
        fileInfo->finderFlags = ff;
    }
    oserr = FSSetCatalogInfo(fsRef, kFSCatInfoFinderInfo, &catalogInfo);
    if (oserr) {
        SETNSERROR(@"FileManagerErrorDomain", -1, @"%@", [OSStatusDescription descriptionForOSStatus:(OSStatus)oserr]);
        return NO;
    }
    return YES;
}
+ (BOOL)applyExtendedFinderFlags:(int)eff to:(FSRef *)fsRef isDirectory:(BOOL)isDirectory error:(NSError **)error {
    FSCatalogInfo catalogInfo;
    OSErr oserr = FSGetCatalogInfo(fsRef, kFSCatInfoFinderXInfo, &catalogInfo, NULL, NULL, NULL);
    if (oserr) {
        SETNSERROR(@"FileManagerErrorDomain", -1, @"%@", [OSStatusDescription descriptionForOSStatus:(OSStatus)oserr]);
        return NO;
    }
    if (isDirectory) {
        ExtendedFolderInfo *extFolderInfo = (ExtendedFolderInfo *)&catalogInfo.extFinderInfo;
        extFolderInfo->extendedFinderFlags = eff;
    } else {
        ExtendedFileInfo *extFileInfo = (ExtendedFileInfo *)&catalogInfo.extFinderInfo;
        extFileInfo->extendedFinderFlags = eff;
    }
    oserr = FSSetCatalogInfo(fsRef, kFSCatInfoFinderXInfo, &catalogInfo);
    if (oserr) {
        SETNSERROR(@"FileManagerErrorDomain", -1, @"%@", [OSStatusDescription descriptionForOSStatus:(OSStatus)oserr]);
        return NO;
    }
    return YES;
}
+ (BOOL)applyFileExtensionHidden:(BOOL)hidden toPath:(NSString *)thePath error:(NSError **)error {
    NSDictionary *attribs = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:hidden], NSFileExtensionHidden, nil];
    return [[NSFileManager defaultManager] setAttributes:attribs ofItemAtPath:thePath error:error];
}
+ (BOOL)applyUID:(int)uid gid:(int)gid toPath:(NSString *)thePath error:(NSError **)error {
    HSLogDebug(@"chown(%@, %d, %d)", thePath, uid, gid);
    if (lchown([thePath fileSystemRepresentation], uid, gid) == -1) {
        int errnum = errno;
        HSLogError(@"lchown(%@) error %d: %s", thePath, errnum, strerror(errnum));
        SETNSERROR(@"UnixErrorDomain", errnum, @"error changing ownership of %@: %s", thePath, strerror(errnum));
        return NO;
    }
    HSLogDebug(@"lchown(%@, %d, %d); euid=%d", thePath, uid, gid, geteuid());
    return YES;
}
+ (BOOL)applyMode:(int)mode toPath:(NSString *)thePath isDirectory:(BOOL)isDirectory error:(NSError **)error {
    if (isDirectory) {
        int ret = chmod([thePath fileSystemRepresentation], mode);
        if (ret == -1) {
            int errnum = errno;
            HSLogError(@"chmod(%@, %d) error %d: %s", thePath, mode, errnum, strerror(errnum));
            SETNSERROR(@"UnixErrorDomain", errnum, @"failed to set permissions on %@: %s", thePath, strerror(errnum));
            return NO;
        }
        HSLogDebug(@"chmod(%@, 0%6o)", thePath, mode);
    } else {
        int fd = open([thePath fileSystemRepresentation], O_RDWR|O_SYMLINK);
        if (fd == -1) {
            int errnum = errno;
            HSLogError(@"open(%@) error %d: %s", thePath, errnum, strerror(errnum));
            SETNSERROR(@"UnixErrorDomain", errnum, @"failed to open %@: %s", thePath, strerror(errnum));
            return NO;
        }
        int ret = fchmod(fd, mode);
        close(fd);
        if (ret == -1) {
            int errnum = errno;
            HSLogError(@"fchmod(%@) error %d: %s", thePath, errnum, strerror(errnum));
            SETNSERROR(@"UnixErrorDomain", errnum, @"failed to set permissions on %@: %s", thePath, strerror(errnum));
            return NO;
        }
        HSLogDebug(@"fchmod(%@, 0%6o)", thePath, mode);
    }
    return YES;
}
+ (BOOL)applyMTimeSec:(int64_t)mtime_sec mTimeNSec:(int64_t)mtime_nsec toPath:(NSString *)thePath error:(NSError **)error {
    struct timespec mtimeSpec = { (__darwin_time_t)mtime_sec, (__darwin_time_t)mtime_nsec };
    struct timeval atimeVal;
    struct timeval mtimeVal;
    TIMESPEC_TO_TIMEVAL(&atimeVal, &mtimeSpec); // Just use mtime because we don't have atime, nor do we care about atime.
    TIMESPEC_TO_TIMEVAL(&mtimeVal, &mtimeSpec);
    struct timeval timevals[2];
    timevals[0] = atimeVal;
    timevals[1] = mtimeVal;
    if (utimes([thePath fileSystemRepresentation], timevals) == -1) {
        int errnum = errno;
        HSLogError(@"utimes(%@) error %d: %s", thePath, errnum, strerror(errnum));
        SETNSERROR(@"UnixErrorDomain", errnum, @"failed to set timestamps on %@: %s", thePath, strerror(errnum));
        return NO;
    }
    return YES;
}
+ (BOOL)applyCreateTimeSec:(int64_t)theCreateTime_sec createTimeNSec:(int64_t)theCreateTime_nsec to:(FSRef *)fsRef error:(NSError **)error {
    FSCatalogInfo catalogInfo;
    OSErr oserr = FSGetCatalogInfo(fsRef, kFSCatInfoCreateDate, &catalogInfo, NULL, NULL, NULL);
    if (oserr) {
        SETNSERROR(@"FileManagerErrorDomain", -1, @"%@", [OSStatusDescription descriptionForOSStatus:(OSStatus)oserr]);
        return NO;
    }
    CFTimeInterval theCreateTime = (double)theCreateTime_sec - NSTimeIntervalSince1970 + (double)theCreateTime_nsec / 1000000000.0;
    if (UCConvertCFAbsoluteTimeToUTCDateTime(theCreateTime, &catalogInfo.createDate) != noErr) {
        SETNSERROR(@"FileManagerErrorDomain", -1, @"unable to convert CFAbsoluteTime %f to UTCDateTime", theCreateTime);
        return NO;
    }
    oserr = FSSetCatalogInfo(fsRef, kFSCatInfoCreateDate, &catalogInfo);
    if (oserr) {
        SETNSERROR(@"FileManagerErrorDomain", -1, @"%@", [OSStatusDescription descriptionForOSStatus:(OSStatus)oserr]);
        return NO;
    }
    return YES;
}
@end
