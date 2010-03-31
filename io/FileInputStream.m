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

#import "FileInputStream.h"
#import "SetNSError.h"
#import "InputStreams.h"
#import "NSErrorCodes.h"

#define MY_BUF_SIZE (4096)

@interface FileInputStream (internal)
- (void)close;
@end

@implementation FileInputStream
- (id)initWithPath:(NSString *)thePath length:(unsigned long long)theLength {
    if (self = [super init]) {
        fd = -1;
        path = [thePath retain];
        fileLength = theLength;
        buf = (unsigned char *)malloc(MY_BUF_SIZE);
    }
    return self;
}
- (id)initWithPath:(NSString *)thePath offset:(unsigned long long)theOffset length:(unsigned long long)theLength {
    if (self = [super init]) {
        fd = -1;
        path = [thePath retain];
        fileLength = theOffset + theLength;
        buf = (unsigned char *)malloc(MY_BUF_SIZE);
        offset = theOffset;
    }
    return self;
}
- (void)dealloc {
    [self close];
    [path release];
    free(buf);
    [super dealloc];
}
- (unsigned char *)read:(NSUInteger *)length error:(NSError **)error {
    return [self readMaximum:MY_BUF_SIZE length:length error:error];
}
- (unsigned char *)readMaximum:(NSUInteger)maximum length:(NSUInteger *)length error:(NSError **)error {
    if (fd == -1) {
        fd = open([path fileSystemRepresentation], O_RDONLY|O_NOFOLLOW);
        if (fd == -1) {
            SETNSERROR(@"UnixErrorDomain", errno, @"%s", strerror(errno));
            return NO;
        }
        HSLogTrace(@"opened fd %d (%@)", fd, path);
        if (offset > 0) {
            if (lseek(fd, (off_t)offset, SEEK_SET) == -1) {
                SETNSERROR(@"UnixErrorDomain", errno, @"lseek(%@, %qu): %s", path, offset, strerror(errno));
                return NO;
            }
        }
    }
    int ret;
    unsigned long long remaining = fileLength - offset;
    unsigned long long toRead = (maximum > remaining) ? remaining : maximum;
    if (toRead > MY_BUF_SIZE) {
        toRead = MY_BUF_SIZE;
    }
    if (toRead == 0) {
        SETNSERROR(@"StreamsErrorDomain", ERROR_EOF, @"reached EOF");
        return NULL;
    }
read_again:
    ret = read(fd, buf, (size_t)toRead);
    if ((ret == -1) && (errno == EINTR)) {
        goto read_again;
    }
    if (ret == -1) {
        SETNSERROR(@"UnixErrorDomain", errno, @"read: %s", strerror(errno));
        return NULL;
    }
    if (ret == 0) {
        SETNSERROR(@"StreamsErrorDomain", ERROR_EOF, @"EOF on %@", path);
        return NULL;
    }
    offset += (unsigned long long)ret;
    *length = (NSUInteger)ret;
    bytesReceived += (uint64_t)ret;
    return buf;
}
- (NSData *)slurp:(NSError **)error {
    return [InputStreams slurp:self error:error];
}

#pragma mark BufferedInputStream
- (unsigned char *)readExactly:(NSUInteger)exactLength error:(NSError **)error {
    if (exactLength > 2147483648) {
        SETNSERROR(@"InputStreamErrorDomain", -1, @"absurd length %u requested", exactLength);
        return NULL;
    }
    NSMutableData *data = [NSMutableData dataWithLength:exactLength];
    unsigned char *dataBuf = [data mutableBytes];
    NSUInteger total = 0;
    while (total < exactLength) {
        NSUInteger maximum = exactLength - total;
        NSUInteger length;
        unsigned char *ibuf = [self readMaximum:maximum length:&length error:error];
        if (ibuf == NULL) {
            return NULL;
        }
        NSAssert(length > 0, @"expected more than 0 bytes");
        memcpy(dataBuf + total, ibuf, length);
        total += length;
    }
    return dataBuf;
}
- (uint64_t)bytesReceived {
    return bytesReceived;
}
- (void)bytesWereNotUsed {
}

#pragma mark NSObject protocol
- (NSString *)description {
    return [NSString stringWithFormat:@"<FileInputStream: fd=%d path=%@>", fd, path];
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
