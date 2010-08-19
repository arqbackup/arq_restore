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

#include <sys/stat.h>
#include <sys/xattr.h>
#import "XAttrSet.h"
#import "StringIO.h"
#import "DataIO.h"
#import "IntegerIO.h"
#import "Blob.h"
#import "DataInputStream.h"
#import "SetNSError.h"
#import "NSErrorCodes.h"
#import "Streams.h"
#import "NSError_extra.h"

#define HEADER_LENGTH (12)

@interface XAttrSet (internal)
- (BOOL)loadFromPath:(NSString *)thePath error:(NSError **)error;
- (BOOL)loadFromInputStream:(id <BufferedInputStream>)is error:(NSError **)error;
@end

@implementation XAttrSet
- (id)initWithPath:(NSString *)thePath error:(NSError **)error {
    if (self = [super init]) {
        xattrs = [[NSMutableDictionary alloc] init];
        NSError *myError = nil;
        if (![self loadFromPath:thePath error:&myError]) {
            if ([myError isErrorWithDomain:@"UnixErrorDomain" code:EPERM]) {
                HSLogDebug(@"%@ doesn't support extended attributes; skipping", thePath);
            } else {
                if (error != NULL) {
                    *error = myError;
                }
                [self release];
                self = nil;
            }
        }
    }
    return self;
}
- (id)initWithBufferedInputStream:(id <BufferedInputStream>)is error:(NSError **)error {
    if (self = [super init]) {
        xattrs = [[NSMutableDictionary alloc] init];
        if (![self loadFromInputStream:is error:error]) {
            [self release];
            self = nil;
        }
    }
    return self;
}
- (void)dealloc {
    [xattrs release];
    [super dealloc];
}
- (Blob *)toBlob {
    NSMutableData *data = [[NSMutableData alloc] init];
    [data appendBytes:"XAttrSetV002" length:HEADER_LENGTH];
    uint64_t count = (uint64_t)[xattrs count];
    [IntegerIO writeUInt64:count to:data];
    for (NSString *name in [xattrs allKeys]) {
        [StringIO write:name to:data];
        [DataIO write:[xattrs objectForKey:name] to:data];
    }
    Blob *ret = [[[Blob alloc] initWithData:data mimeType:@"binary/octet-stream" downloadName:@"xattrset"] autorelease];    
    [data release];
    return ret;
}
- (NSUInteger)count {
    return [xattrs count];
}
- (unsigned long long)dataLength {
    unsigned long long total = 0;
    for (NSString *key in [xattrs allKeys]) {
        NSData *value = [xattrs objectForKey:key];
        total += [value length];
    }
    return total;
}
- (NSArray *)names {
    return [xattrs allKeys];
}
- (BOOL)applyToFile:(NSString *)path error:(NSError **)error {
    XAttrSet *current = [[[XAttrSet alloc] initWithPath:path error:error] autorelease];
    if (!current) {
        return NO;
    }
    const char *pathChars = [path fileSystemRepresentation];
    for (NSString *name in [current names]) {
        if (removexattr(pathChars, [name UTF8String], XATTR_NOFOLLOW) == -1) {
            SETNSERROR(@"UnixErrorDomain", errno, @"removexattr: %s", strerror(errno));
            return NO;
        }
    }
    for (NSString *key in [xattrs allKeys]) {
        NSData *value = [xattrs objectForKey:key];
        if (setxattr(pathChars, 
                     [key UTF8String],
                     [value bytes],
                     [value length],
                     0,
                     XATTR_NOFOLLOW) == -1) {
            SETNSERROR(@"UnixErrorDomain", errno, @"setxattr: %s", strerror(errno));
            return NO;
        }
    }
    return YES;
}
@end

@implementation XAttrSet (internal)
- (BOOL)loadFromPath:(NSString *)thePath error:(NSError **)error {
    struct stat st;
    if (lstat([thePath fileSystemRepresentation], &st) == -1) {
        SETNSERROR(@"UnixErrorDomain", errno, @"lstat(%@): %s", thePath, strerror(errno));
        return NO;
    }
    if (S_ISREG(st.st_mode) || S_ISDIR(st.st_mode) || S_ISLNK(st.st_mode)) {
        const char *path = [thePath fileSystemRepresentation];
        ssize_t xattrsize = listxattr(path, NULL, 0, XATTR_NOFOLLOW);
        if (xattrsize == -1) {
            SETNSERROR(@"UnixErrorDomain", errno, @"%s", strerror(errno));
            return NO;
        } 
        if (xattrsize > 0) {
            char *xattrbuf = (char *)malloc(xattrsize);
            xattrsize = listxattr(path, xattrbuf, xattrsize, XATTR_NOFOLLOW);
            if (xattrsize == -1) {
                SETNSERROR(@"UnixErrorDomain", errno, @"%s", strerror(errno));
                free(xattrbuf);
                return NO;
            }
            for (char *name = xattrbuf; name < (xattrbuf + xattrsize); name += strlen(name) + 1) {
                NSString *theName = [NSString stringWithUTF8String:name];
                ssize_t valuesize = getxattr(path, name, NULL, 0, 0, XATTR_NOFOLLOW);
                NSData *xattrData = nil;
                if (valuesize == -1) {
                    SETNSERROR(@"UnixErrorDomain", errno, @"Error reading extended attribute %s: %s", name, strerror(errno));
                    free(xattrbuf);
                    return NO;
                }
                if (valuesize > 0) {
                    void *value = malloc(valuesize);
                    if (getxattr(path, name, value, valuesize, 0, XATTR_NOFOLLOW) == -1) {
                        SETNSERROR(@"UnixErrorDomain", errno, @"getxattr: %s", strerror(errno));
                        free(value);
                        free(xattrbuf);
                        return NO;
                    }
                    xattrData = [NSData dataWithBytes:value length:valuesize];
                    free(value);
                } else {
                    xattrData = [NSData data];
                }
                [xattrs setObject:xattrData forKey:theName];
            }
            free(xattrbuf);
        }
    }
    return YES;
}
- (BOOL)loadFromInputStream:(id <BufferedInputStream>)is error:(NSError **)error {
    unsigned char *headerBytes = [is readExactly:HEADER_LENGTH error:error];
    if (headerBytes == NULL) {
        return NO;
    }
    if (strncmp((const char *)headerBytes, "XAttrSetV002", HEADER_LENGTH)) {
        SETNSERROR(@"XAttrSetErrorDomain", ERROR_INVALID_OBJECT_VERSION, @"invalid XAttrSet header");
        return NO;
    }
    uint64_t count;
    if (![IntegerIO readUInt64:&count from:is error:error]) {
        return NO;
    }
    for (uint64_t i = 0; i < count; i++) {
        NSString *name;
        if (![StringIO read:&name from:is error:error]) {
            return NO;
        }
        NSData *value;
        if (![DataIO read:&value from:is error:error]) {
            return NO;
        }
        [xattrs setObject:value forKey:name];
    }
    return YES;
}
@end
