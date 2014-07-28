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


#import "FileInputStream.h"

#import "InputStreams.h"


#define MY_BUF_SIZE (4096)

@interface FileInputStream (internal)
- (void)close;
@end

@implementation FileInputStream
- (id)initWithPath:(NSString *)thePath offset:(unsigned long long)theOffset length:(unsigned long long)theLength {
    if (self = [super init]) {
        fd = -1;
        path = [thePath retain];
        fileLength = theOffset + theLength;
        offset = theOffset;
    }
    return self;
}
- (void)dealloc {
    [self close];
    [path release];
    [super dealloc];
}

#pragma mark InputStream
- (NSInteger)read:(unsigned char *)buf bufferLength:(NSUInteger)bufferLength error:(NSError **)error {
    if (fd == -1) {
        fd = open([path fileSystemRepresentation], O_RDONLY|O_NOFOLLOW);
        if (fd == -1) {
            int errnum = errno;
            HSLogError(@"open(%@) error %d: %s", path, errnum, strerror(errnum));
            SETNSERROR(@"UnixErrorDomain", errnum, @"failed to open %@: %s", path, strerror(errnum));
            return -1;
        }
        HSLogTrace(@"opened fd %d (%@)", fd, path);
        if (offset > 0) {
            if (lseek(fd, (off_t)offset, SEEK_SET) == -1) {
                int errnum = errno;
                HSLogError(@"lseek(%@, %qu) error %d: %s", path, offset, errnum, strerror(errnum));
                SETNSERROR(@"UnixErrorDomain", errnum, @"failed to seek to %qu in %@: %s", offset, path, strerror(errnum));
                return -1;
            }
        }
    }
    unsigned long long fileRemaining = fileLength - offset;
    unsigned long long toRead = fileRemaining > bufferLength ? bufferLength : fileRemaining;
    if (toRead == 0) {
        return 0;
    }
    
    NSInteger ret = 0;
read_again:
    ret = read(fd, buf, (size_t)toRead);
    if ((ret == -1) && (errno == EINTR)) {
        goto read_again;
    }
    if (ret < 0) {
        int errnum = errno;
        HSLogError(@"read(%@) error %d: %s", path, errnum, strerror(errnum));
        SETNSERROR(@"UnixErrorDomain", errnum, @"failed to read from %@: %s", path, strerror(errnum));
    } else {
        offset += ret;
    }
    return ret;
}
- (NSData *)slurp:(NSError **)error {
    return [InputStreams slurp:self error:error];
}

#pragma mark NSObject protocol
- (NSString *)description {
    return [NSString stringWithFormat:@"<FileInputStream: offset=%qu,length=%qu,path=%@>", offset, fileLength, path];
}
@end

@implementation FileInputStream (internal)
- (void)close {
    if (fd != -1) {
        close(fd);
        HSLogTrace(@"closed fd %d (%@)", fd, path);
        fd = -1;
    }
}
@end
