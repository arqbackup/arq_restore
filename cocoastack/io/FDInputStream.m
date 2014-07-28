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



#import "FDInputStream.h"

#import "InputStreams.h"


#define MY_BUF_SIZE (4096)
#define DEFAULT_READ_TIMEOUT_SECONDS (60)

@implementation FDInputStream
- (id)initWithFD:(int)theFD label:(NSString *)theLabel {
    return [self initWithFD:theFD timeoutSeconds:0 label:theLabel];
}
- (id)initWithFD:(int)theFD offset:(unsigned long long)theOffset length:(unsigned long long)theLength label:(NSString *)theLabel {
    if (self = [super init]) {
        fd = theFD;
        offset = theOffset;
        length = theLength;
        label = [theLabel retain];
        needsSeek = YES;
        hasLength = YES;
    }
    return self;
}
- (id)initWithFD:(int)theFD timeoutSeconds:(NSUInteger)theTimeoutSeconds label:(NSString *)theLabel {
    if (self = [super init]) {
        fd = theFD;
        timeoutSeconds = theTimeoutSeconds;
        label = [theLabel retain];
    }
    return self;
}
- (void)dealloc {
    [label release];
    [super dealloc];
}

#pragma mark InputStream
- (NSInteger)read:(unsigned char *)buf bufferLength:(NSUInteger)bufferLength error:(NSError **)error {
    if (needsSeek) {
        if (lseek(fd, offset, SEEK_SET) == -1) {
            int errnum = errno;
            HSLogError(@"lseek(%d) error %d: %s", fd, errnum, strerror(errnum));
            SETNSERROR(@"UnixErrorDomain", errnum, @"failed to seek to %qu in file descriptor %d: %s", offset, fd, strerror(errnum));
            return -1;
        }
        needsSeek = NO;
    }
    
    if (hasLength) {
        unsigned long long remaining = length - bytesReceived;
        if (remaining == 0) {
            return 0;
        }
        if ((unsigned long long)bufferLength > remaining) {
            bufferLength = (NSUInteger)remaining;
        }
    }
    
    NSInteger ret = 0;
    fd_set readSet;
    fd_set exceptSet;
    FD_ZERO(&readSet);
    FD_SET((unsigned int)fd, &readSet);
    FD_ZERO(&exceptSet);
    FD_SET((unsigned int)fd, &exceptSet);
    
    struct timeval timeout;
    struct timeval *pTimeout = NULL;
    if (timeoutSeconds > 0) {
        timeout.tv_sec = timeoutSeconds;
        timeout.tv_usec = 0;
        pTimeout = &timeout;
    }
    
select_again:
    ret = select(fd + 1, &readSet, 0, &exceptSet, pTimeout);
    if ((ret == -1) && (errno == EINTR)) {
        goto select_again;
    } else if (ret == -1) {
        int errnum = errno;
        HSLogError(@"select on %@ (fd=%d) error %d: %s", label, fd, errnum, strerror(errnum));
        SETNSERROR(@"UnixErrorDomain", errnum, @"select: %s", strerror(errnum));
        return -1;
    } else if (ret == 0) {
        SETNSERROR(@"InputStreamErrorDomain", ERROR_TIMEOUT, @"read timeout");
        return -1;
    }
    
read_again:
    ret = read(fd, buf, bufferLength);
    if ((ret == -1) && (errno == EINTR)) {
        goto read_again;
    } else if (ret == -1) {
        int errnum = errno;
        HSLogError(@"read from %@ (fd=%d) error %d: %s", label, fd, errnum, strerror(errnum));
        SETNSERROR(@"UnixErrorDomain", errnum, @"failed to read from %@: %s", label, strerror(errnum));
        return -1;
    }
    if (ret > 0) {
        bytesReceived += ret;
    }
    return ret;
}
- (NSData *)slurp:(NSError **)error {
    return [InputStreams slurp:self error:error];
}

#pragma mark NSObject protocol
- (NSString *)description {
    NSMutableString *ret = [NSMutableString stringWithFormat:@"<FDInputStream fd=%d", fd];
    if (hasLength) {
        [ret appendFormat:@" offset=%qu length=%qu", offset, length];
    }
    if (label != nil) {
        [ret appendString:@" "];
        [ret appendString:label];
    }
    return ret;
}
@end
