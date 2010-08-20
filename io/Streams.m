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

#import "Streams.h"
#import "SetNSError.h"
#import "FDOutputStream.h"
#import "NSErrorCodes.h"
#import "InputStream.h"

@implementation Streams
+ (BOOL)transferFrom:(id <InputStream>)is to:(id <OutputStream>)os error:(NSError **)error {
    BOOL ret = YES;
    for (;;) {
        NSUInteger received;
        NSError *readError = nil;
        unsigned char *buf = [is read:&received error:&readError];
        if (buf == NULL) {
            if ([readError code] != ERROR_EOF) {
                ret = NO;
                if (error != NULL) {
                    *error = readError;
                }
            }
            break;
        }
        NSAssert(received > 0, @"expected to receive more than 0 bytes");
        if (![os write:buf length:received error:error]) {
            ret = NO;
            break;
        }
    }
    return ret;
}
+ (BOOL)transferFrom:(id <InputStream>)is atomicallyToFile:(NSString *)path bytesWritten:(unsigned long long *)written error:(NSError **)error {
    NSString *tempFileTemplate = [path stringByAppendingString:@".XXXXXX"];
    const char *tempFileTemplateCString = [tempFileTemplate fileSystemRepresentation];
    char *tempFileCString = strdup(tempFileTemplateCString);
    int fd = mkstemp(tempFileCString);
    NSString *tempFile = [[NSFileManager defaultManager] stringWithFileSystemRepresentation:tempFileCString length:strlen(tempFileCString)];
    free(tempFileCString);
    if (fd == -1) {
        SETNSERROR(@"UnixErrorDomain", errno, @"mkstemp(%s): %s", tempFileCString, strerror(errno));
        return NO;
    }
    FDOutputStream *fos = [[FDOutputStream alloc] initWithFD:fd];
    BOOL ret = [Streams transferFrom:is to:fos error:error];
    if (ret) {
        if (rename([tempFile fileSystemRepresentation], [path fileSystemRepresentation]) == -1) {
            SETNSERROR(@"UnixErrorDomain", errno, @"rename(%@, %@): %s", tempFile, path, strerror(errno));
            ret = NO;
        }
    }
    if (ret) {
        *written = [fos bytesWritten];
    } else {
        HSLogError(@"error transferring bytes to %@", path);
    }
    [fos release];
    close(fd);
    return ret;
}
@end
