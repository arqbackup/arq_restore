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


#import "FileOutputStream.h"


@interface FileOutputStream (internal)
- (BOOL)open:(NSError **)error;
@end

@implementation FileOutputStream
- (id)initWithPath:(NSString *)thePath append:(BOOL)isAppend {
    if (self = [super init]) {
        path = [thePath copy];
        append = isAppend;
        fd = -1;
    }
    return self;
}
- (id)initWithPath:(NSString *)thePath targetUID:(uid_t)theTargetUID targetGID:(gid_t)theTargetGID append:(BOOL)isAppend {
    if (self = [super init]) {
        path = [thePath copy];
        targetUID = [[NSNumber alloc] initWithUnsignedInt:theTargetUID];
        targetGID = [[NSNumber alloc] initWithUnsignedInt:theTargetGID];
        append = isAppend;
        fd = -1;
    }
    return self;
}
- (void)dealloc {
    if (fd != -1) {
        close(fd);
    }
    [targetUID release];
    [targetGID release];
    [path release];
    [super dealloc];
}
- (void)close {
    if (fd != -1) {
        close(fd);
        fd = -1;
    }
}
- (BOOL)seekTo:(unsigned long long)offset error:(NSError **)error {
    if (fd == -1 && ![self open:error]) {
        return NO;
    }
    if (lseek(fd, (off_t)offset, SEEK_SET) == -1) {
        int errnum = errno;
        HSLogError(@"lseek(%@, %qu) error %d: %s", path, offset, errnum, strerror(errnum));
        SETNSERROR(@"UnixErrorDomain", errnum, @"failed to seek to %qu in %@: %s", offset, path, strerror(errnum));
        return NO;
    }
    return YES;
}
- (NSString *)path {
    return path;
}
- (NSInteger)write:(const unsigned char *)buf length:(NSUInteger)len error:(NSError **)error {
    if (fd == -1 && ![self open:error]) {
        return -1;
    }
    NSInteger ret = 0;
write_again:
    ret = write(fd, buf, len);
    if ((ret < 0) && (errno == EINTR)) {
        goto write_again;
    }
    if (ret < 0) {
        int errnum = errno;
        HSLogError(@"write(%@) error %d: %s", path, errnum, strerror(errnum));
        SETNSERROR(@"UnixErrorDomain", errnum, @"error writing to %@: %s", path, strerror(errnum));
        return ret;
    }
    bytesWritten += (NSUInteger)ret;
    return ret;
}
- (unsigned long long)bytesWritten {
    return bytesWritten;
}

#pragma mark NSObject
- (NSString *)description {
    return [NSString stringWithFormat:@"<FileOutputStream: path=%@>", path];
}
@end

@implementation FileOutputStream (internal)
- (BOOL)open:(NSError **)error {
    int oflag = O_WRONLY|O_CREAT;
    if (append) {
        oflag |= O_APPEND;
    } else {
        oflag |= O_TRUNC;
    }
    mode_t mode = S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH;
    fd = open([path fileSystemRepresentation], oflag, mode);
    if (fd == -1) {
        int errnum = errno;
        HSLogError(@"open(%@) error %d: %s", path, errnum, strerror(errnum));
        SETNSERROR(@"UnixErrorDomain", errnum, @"failed to open %@: %s", path, strerror(errnum));
        return NO;
    }
    if (targetUID != nil && targetGID != nil) {
        if (fchown(fd, [targetUID unsignedIntValue], [targetGID unsignedIntValue]) == -1) {
            int errnum = errno;
            HSLogError(@"fchown(%@) error %d: %s", path, errnum, strerror(errnum));
            SETNSERROR(@"UnixErrorDomain", errnum, @"failed to change ownership of %@: %s", path, strerror(errnum));
            return NO;
        }
    }
    return YES;
}
@end

