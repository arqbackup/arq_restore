/*
 Copyright (c) 2009-2010, Stefan Reitshamer http://www.haystacksoftware.com
 
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

#import "FDInputStream.h"
#import "SetNSError.h"
#import "InputStreams.h"
#import "NSErrorCodes.h"

#define MY_BUF_SIZE (4096)
#define DEFAULT_READ_TIMEOUT_SECONDS (60)

static time_t readTimeoutSeconds = DEFAULT_READ_TIMEOUT_SECONDS;

@implementation FDInputStream
+ (void)setReadTimeoutSeconds:(time_t)timeout {
    readTimeoutSeconds = timeout;
    HSLogInfo(@"network read timeout set to %d seconds", timeout);
}
- (id)initWithFD:(int)theFD {
    if (self = [super init]) {
        fd = theFD;
    }
    return self;
}
- (void)dealloc {
    [super dealloc];
}
- (unsigned char *)read:(NSUInteger *)length error:(NSError **)error {
    return [self readMaximum:MY_BUF_SIZE length:length error:error];
}
- (unsigned char *)readMaximum:(NSUInteger)maximum length:(NSUInteger *)length error:(NSError **)error {
    NSUInteger toRead = (MY_BUF_SIZE > maximum) ? maximum : MY_BUF_SIZE;
    NSMutableData *data = [NSMutableData dataWithLength:toRead];
    unsigned char *buf = (unsigned char *)[data mutableBytes];
    int ret = 0;
    fd_set readSet;
    fd_set exceptSet;
    FD_ZERO(&readSet);
    FD_SET((unsigned int)fd, &readSet);
    FD_ZERO(&exceptSet);
    FD_SET((unsigned int)fd, &exceptSet);
    struct timeval timeout;
    struct timeval *pTimeout;
    
select_again:
    timeout.tv_sec = readTimeoutSeconds;
    timeout.tv_usec = 0;
    pTimeout = (readTimeoutSeconds > 0) ? &timeout : 0;
    ret = select(fd + 1, &readSet, 0, &exceptSet, pTimeout);
    if ((ret == -1) && (errno == EINTR)) {
        goto select_again;
    } else if (ret == -1) {
        SETNSERROR(@"UnixErrorDomain", errno, @"select: %s", strerror(errno));
        return NULL;
    } else if (ret == 0) {
        SETNSERROR(@"InputStreamErrorDomain", -1, @"read timeout");
        return NULL;
    }
    
read_again:
    ret = read(fd, buf, toRead);
    if ((ret == -1) && (errno == EINTR)) {
        goto read_again;
    } else if (ret == -1) {
        SETNSERROR(@"UnixErrorDomain", errno, @"read: %s", strerror(errno));
        return NULL;
    }
    if (ret == 0) {
        SETNSERROR(@"StreamErrorDomain", ERROR_EOF, @"EOF on fd %d", fd);
        return NULL;
    }
    *length = (NSUInteger)ret;
    bytesReceived += (uint64_t)ret;
    return buf;
}
- (NSData *)slurp:(NSError **)error {
    return [InputStreams slurp:self error:error];
}

#pragma mark BufferedInputStream protocol
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
    bytesReceived += (uint64_t)exactLength;
    return dataBuf;
}
- (uint64_t)bytesReceived {
    return bytesReceived;
}
#pragma mark NSObject protocol
- (NSString *)description {
    return [NSString stringWithFormat:@"<FDInputStream: fd=%d>", fd];
}
@end
