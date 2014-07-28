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



#include <sys/time.h>
#include <sys/stat.h>
#import "NSFileManager_extra.h"

#import "FileInputStream.h"
#import "Streams.h"

@implementation NSFileManager (extra)
- (BOOL)ensureParentPathExistsForPath:(NSString *)path error:(NSError **)error {
    NSString *parentPath = [path stringByDeletingLastPathComponent];
    BOOL isDirectory = NO;
    if ([self fileExistsAtPath:parentPath isDirectory:&isDirectory]) {
        if (!isDirectory) {
            SETNSERROR(@"FileErrorDomain", -1, @"parent path %@ exists and is not a directory", parentPath);
            return NO;
        }
    } else if (![self createDirectoryAtPath:parentPath withIntermediateDirectories:YES attributes:nil error:error]) {
        return NO;
    }
    return YES;
}
- (BOOL)ensureParentPathExistsForPath:(NSString *)path 
                            targetUID:(uid_t)theTargetUID 
                            targetGID:(gid_t)theTargetGID
                                error:(NSError **)error {
    NSString *parentPath = [path stringByDeletingLastPathComponent];
    if (![self fileExistsAtPath:parentPath] && ![self createDirectoryAtPath:parentPath 
                                                withIntermediateDirectories:YES attributes:nil 
                                                                  targetUID:theTargetUID 
                                                                  targetGID:theTargetGID
                                                                      error:error]) {
        return NO;
    }
    return YES;
}
- (BOOL)createDirectoryAtPath:(NSString *)path 
  withIntermediateDirectories:(BOOL)withIntermediate
                   attributes:(NSDictionary *)attributes 
                    targetUID:(uid_t)theTargetUID 
                    targetGID:(gid_t)theTargetGID
                        error:(NSError **)error {
    if (![self fileExistsAtPath:path]) {
        if (![path isEqualToString:@"/"]) {
            if (![self ensureParentPathExistsForPath:path targetUID:theTargetUID targetGID:theTargetGID error:error]) {
                return NO;
            }
        }
        if (mkdir([path fileSystemRepresentation], 0777) == -1) {
            int errnum = errno;
            HSLogError(@"mkdir(%@) error %d: %s", path, errnum, strerror(errnum));
            SETNSERROR(@"UnixErrorDomain", errnum, @"failed to make directory %@: %s", path, strerror(errnum));
            return NO;
        }
        // According to mkdir(2), we have to explicitly set the sticky/executable bits after calling mkdir:
        if (chmod([path fileSystemRepresentation], 0777) == -1) {
            int errnum = errno;
            HSLogError(@"chmod(%@) error %d: %s", path, errnum, strerror(errnum));
            SETNSERROR(@"UnixErrorDomain", errnum, @"failed to change permissions of %@: %s", path, strerror(errnum));
            return NO;
        }
        if (chown([path fileSystemRepresentation], theTargetUID, theTargetGID) == -1) {
            int errnum = errno;
            HSLogError(@"chown(%@) error %d: %s", path, errnum, strerror(errnum));
            SETNSERROR(@"UnixErrorDomain", errnum, @"failed to change ownership of %@: %s", path, strerror(errnum));
            return NO;
        }
    }
    return YES;
}
- (BOOL)touchFileAtPath:(NSString *)path error:(NSError **)error {
    if ([self fileExistsAtPath:path]) {
        time_t theTime = time(NULL);
        struct timespec spec;
        spec.tv_sec = theTime;
        spec.tv_nsec = 0;
        struct timeval timevals[2];
        TIMESPEC_TO_TIMEVAL(&(timevals[0]), &spec);
        TIMESPEC_TO_TIMEVAL(&(timevals[1]), &spec);
        if (utimes([path fileSystemRepresentation], timevals) == -1) {
            int errnum = errno;
            HSLogError(@"utimes(%@) error %d: %s", path, errnum, strerror(errnum));
            SETNSERROR(@"UnixErrorDomain", errnum, @"failed to change timestamps of %@: %s", path, strerror(errnum));
            return NO;
        }
    } else {
        int fd = open([path fileSystemRepresentation], O_CREAT, S_IRWXU | S_IRWXG | S_IRWXO);
        if (fd == -1) {
            int errnum = errno;
            HSLogError(@"open(%@) error %d: %s", path, errnum, strerror(errnum));
            SETNSERROR(@"UnixErrorDomain", errnum, @"failed to open %@: %s", path, strerror(errnum));
            return NO;
        }
        close(fd);
    }
    return YES;
}
- (BOOL)touchFileAtPath:(NSString *)path 
              targetUID:(uid_t)theTargetUID 
              targetGID:(gid_t)theTargetGID
                  error:(NSError **)error {
    if ([self fileExistsAtPath:path]) {
        time_t theTime = time(NULL);
        struct timespec spec;
        spec.tv_sec = theTime;
        spec.tv_nsec = 0;
        struct timeval timevals[2];
        TIMESPEC_TO_TIMEVAL(&(timevals[0]), &spec);
        TIMESPEC_TO_TIMEVAL(&(timevals[1]), &spec);
        if (utimes([path fileSystemRepresentation], timevals) == -1) {
            int errnum = errno;
            HSLogError(@"utimes(%@) error %d: %s", path, errnum, strerror(errnum));
            SETNSERROR(@"UnixErrorDomain", errnum, @"failed to change timestamps of %@: %s", path, strerror(errnum));
            return NO;
        }
    } else {
        int fd = open([path fileSystemRepresentation], O_CREAT, S_IRWXU | S_IRWXG | S_IRWXO);
        if (fd == -1) {
            int errnum = errno;
            HSLogError(@"open(%@) error %d: %s", path, errnum, strerror(errnum));
            SETNSERROR(@"UnixErrorDomain", errnum, @"failed to open %@: %s", path, strerror(errnum));
            return NO;
        }
        if (fchown(fd, theTargetUID, theTargetGID) == -1) {
            close(fd);
            int errnum = errno;
            HSLogError(@"fchown(%@) error %d: %s", path, errnum, strerror(errnum));
            SETNSERROR(@"UnixErrorDomain", errnum, @"failed to change ownership of %@: %s", path, strerror(errnum));
            return NO;
        }
        close(fd);
    }
    return YES;
}
- (BOOL)createUniqueTempDirectoryWithTemplate:(NSString *)pathTemplate createdDirectory:(NSString **)createdPath error:(NSError **)error {
    *createdPath = nil;
    char *cTemplate = strdup([pathTemplate fileSystemRepresentation]);
    char *tempDir = mkdtemp(cTemplate);
    if (tempDir != NULL) {
        *createdPath = [NSString stringWithUTF8String:tempDir];
    } else {
        int errnum = errno;
        HSLogError(@"mkdtemp(%@) error %d: %s", pathTemplate, errnum, strerror(errnum));
        SETNSERROR(@"UnixErrorDomain", errnum, @"failed to make temporary directory with template %@: %s", pathTemplate, strerror(errnum));
    }
    free(cTemplate);
    return tempDir != NULL;
}
@end
