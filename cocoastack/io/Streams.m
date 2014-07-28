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



#import "Streams.h"

#import "Sysctl.h"
#import "NetMonitor.h"
#import "FDOutputStream.h"
#import "BufferedOutputStream.h"
#import "DataInputStream.h"


#define MY_BUF_SIZE (4096)

@interface Streams (internal)
+ (BOOL)transferFrom:(id <InputStream>)is toBufferedOutputStream:(BufferedOutputStream *)bos bytesWritten:(unsigned long long *)written error:(NSError **)error;
@end

@implementation Streams
+ (BOOL)transferFrom:(id <InputStream>)is to:(id <OutputStream>)os error:(NSError **)error {
    unsigned long long written = 0;
    return [Streams transferFrom:is to:os bytesWritten:&written error:error];
}
+ (BOOL)transferFrom:(id <InputStream>)is to:(id <OutputStream>)os bytesWritten:(unsigned long long *)written error:(NSError **)error {
    BufferedOutputStream *bos = [[BufferedOutputStream alloc] initWithUnderlyingOutputStream:os];
    BOOL ret = [self transferFrom:is toBufferedOutputStream:bos bytesWritten:written error:error];
    if (ret && ![bos flush:error]) {
        ret = NO;
    }
    [bos release];
    return ret;
}
+ (BOOL)transferFrom:(id <InputStream>)is atomicallyToFile:(NSString *)path bytesWritten:(unsigned long long *)written error:(NSError **)error {
    return [Streams transferFrom:is atomicallyToFile:path targetUID:getuid() targetGID:getgid() bytesWritten:written error:error];
}
+ (BOOL)transferFrom:(id <InputStream>)is atomicallyToFile:(NSString *)path targetUID:(uid_t)theTargetUID targetGID:(gid_t)theTargetGID bytesWritten:(unsigned long long *)written error:(NSError **)error {
    NSString *tempFileTemplate = [path stringByAppendingString:@".XXXXXX"];
    const char *tempFileTemplateCString = [tempFileTemplate fileSystemRepresentation];
    char *tempFileCString = strdup(tempFileTemplateCString);
    int fd = mkstemp(tempFileCString);
    NSString *tempFile = [[NSFileManager defaultManager] stringWithFileSystemRepresentation:tempFileCString length:strlen(tempFileCString)];
    free(tempFileCString);
    if (fd == -1) {
        int errnum = errno;
        HSLogError(@"mkstemp(%@) error %d: %s", tempFileTemplate, errnum, strerror(errnum));
        SETNSERROR(@"UnixErrorDomain", errnum, @"failed to make temp file with template %@: %s", tempFileTemplate, strerror(errnum));
        return NO;
    }
    if (fchown(fd, theTargetUID, theTargetGID) == -1) {
        int errnum = errno;
        HSLogError(@"fchown(%@) error %d: %s", tempFile, errnum, strerror(errnum));
        SETNSERROR(@"UnixErrorDomain", errnum, @"failed to change ownership of %@: %s", tempFile, strerror(errnum));
        return NO;
    }
    
    FDOutputStream *fos = [[FDOutputStream alloc] initWithFD:fd];
    BOOL ret = [Streams transferFrom:is to:fos error:error];
    if (ret) {
        if (rename([tempFile fileSystemRepresentation], [path fileSystemRepresentation]) == -1) {
            int errnum = errno;
            HSLogError(@"rename(%@, %@) error %d: %s", tempFile, path, errnum, strerror(errnum));
            SETNSERROR(@"UnixErrorDomain", errnum, @"failed to rename %@ to %@: %s", tempFile, path, strerror(errnum));
            ret = NO;
        } else {
            [[NSFileManager defaultManager] removeItemAtPath:tempFile error:NULL];
        }
    }
    if (ret) {
        if (written != NULL) {
            *written = [fos bytesWritten];
        }
    } else {
        HSLogError(@"error transferring bytes to %@", path);
    }
    [fos release];
    close(fd);
    return ret;
}
+ (BOOL)writeData:(NSData *)theData atomicallyToFile:(NSString *)path targetUID:(uid_t)theTargetUID targetGID:(gid_t)theTargetGID bytesWritten:(unsigned long long *)written error:(NSError **)error {
    DataInputStream *dis = [[[DataInputStream alloc] initWithData:theData description:@"no description"] autorelease];
    return [Streams transferFrom:dis atomicallyToFile:path targetUID:theTargetUID targetGID:theTargetGID bytesWritten:written error:error];
}
@end

@implementation Streams (internal)
+ (BOOL)transferFrom:(id <InputStream>)is toBufferedOutputStream:(BufferedOutputStream *)bos bytesWritten:(unsigned long long *)written error:(NSError **)error {
    NSInteger received = 0;
    unsigned char *buf = (unsigned char *)malloc(MY_BUF_SIZE);
    for (;;) {
        received = [is read:buf bufferLength:MY_BUF_SIZE error:error];
        if (received <= 0) {
            break;
        }
        if (![bos writeFully:buf length:received error:error]) {
            received = -1;
            break;
        }
        *written += (unsigned long long)received;
    }
    free(buf);
    if (![bos flush:error]) {
        received = -1;
    }
    return received >= 0;
}
@end
