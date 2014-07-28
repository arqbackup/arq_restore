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
#include <sys/xattr.h>
#import "XAttrSet.h"
#import "StringIO.h"
#import "DataIO.h"
#import "IntegerIO.h"
#import "DataInputStream.h"


#import "Streams.h"
#import "NSError_extra.h"
#import "BufferedInputStream.h"
#import "NSData-Gzip.h"

#define HEADER_LENGTH (12)

@interface XAttrSet (internal)
- (BOOL)loadFromPath:(NSString *)thePath error:(NSError **)error;
- (BOOL)loadFromInputStream:(BufferedInputStream *)is error:(NSError **)error;
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
                return nil;
            }
        }
        path = [thePath retain];
    }
    return self;
}
- (id)initWithBufferedInputStream:(BufferedInputStream *)is error:(NSError **)error {
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
    [path release];
    [super dealloc];
}
- (NSData *)toData {
    NSMutableData *mutableData = [[[NSMutableData alloc] init] autorelease];
    [mutableData appendBytes:"XAttrSetV002" length:HEADER_LENGTH];
    uint64_t count = (uint64_t)[xattrs count];
    [IntegerIO writeUInt64:count to:mutableData];
    for (NSString *name in [xattrs allKeys]) {
        [StringIO write:name to:mutableData];
        [DataIO write:[xattrs objectForKey:name] to:mutableData];
    }
    return mutableData;
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
- (BOOL)applyToFile:(NSString *)thePath error:(NSError **)error {
    XAttrSet *current = [[[XAttrSet alloc] initWithPath:thePath error:error] autorelease];
    if (!current) {
        return NO;
    }
    const char *pathChars = [thePath fileSystemRepresentation];
    for (NSString *name in [current names]) {
        if (removexattr(pathChars, [name UTF8String], XATTR_NOFOLLOW) == -1) {
            int errnum = errno;
            HSLogError(@"removexattr(%@, %@) error %d: %s", thePath, name, errnum, strerror(errnum));
            SETNSERROR(@"UnixErrorDomain", errnum, @"failed to remove extended attribute %@ from %@: %s", name, thePath, strerror(errnum));
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
            int errnum = errno;
            HSLogError(@"setxattr(%@, %@) error %d: %s", thePath, key, errnum, strerror(errnum));
            SETNSERROR(@"UnixErrorDomain", errnum, @"failed to set extended attribute %@ on %@: %s", key, thePath, strerror(errnum));
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
        int errnum = errno;
        HSLogError(@"lstat(%@) error %d: %s", thePath, errnum, strerror(errnum));
        SETNSERROR(@"UnixErrorDomain", errnum, @"xattr lstat(%@): %s", thePath, strerror(errnum));
        return NO;
    }
    if (S_ISREG(st.st_mode) || S_ISDIR(st.st_mode) || S_ISLNK(st.st_mode)) {
        const char *cpath = [thePath fileSystemRepresentation];
        ssize_t xattrsize = listxattr(cpath, NULL, 0, XATTR_NOFOLLOW);
        if (xattrsize == -1) {
            int errnum = errno;
            HSLogError(@"listxattr(%@) error %d: %s", thePath, errnum, strerror(errnum));
            SETNSERROR(@"UnixErrorDomain", errnum, @"failed to list extended attributes of %@: %s", thePath, strerror(errnum));
            return NO;
        } 
        if (xattrsize > 0) {
            char *xattrbuf = (char *)malloc(xattrsize);
            xattrsize = listxattr(cpath, xattrbuf, xattrsize, XATTR_NOFOLLOW);
            if (xattrsize == -1) {
                int errnum = errno;
                HSLogError(@"listxattr(%@) error %d: %s", thePath, errnum, strerror(errnum));
                SETNSERROR(@"UnixErrorDomain", errnum, @"failed to list extended attributes of %@: %s", thePath, strerror(errnum));
                free(xattrbuf);
                return NO;
            }
            for (char *name = xattrbuf; name < (xattrbuf + xattrsize); name += strlen(name) + 1) {
                NSString *theName = [NSString stringWithUTF8String:name];
                ssize_t valuesize = getxattr(cpath, name, NULL, 0, 0, XATTR_NOFOLLOW);
                if (valuesize == -1) {
                    int errnum = errno;
                    HSLogError(@"skipping xattrs %s of %s: error %d: %s", name, cpath, errnum, strerror(errnum));
                } else if (valuesize > 0) {
                    void *value = malloc(valuesize);
                    if (getxattr(cpath, name, value, valuesize, 0, XATTR_NOFOLLOW) == -1) {
                        int errnum = errno;
                        HSLogError(@"skipping xattrs %s of %s: error %d: %s", name, cpath, errnum, strerror(errnum));
                    } else {
                        [xattrs setObject:[NSData dataWithBytes:value length:valuesize] forKey:theName];
                    }
                    free(value);
                } else {
                    [xattrs setObject:[NSData data] forKey:theName];
                }
            }
            free(xattrbuf);
        }
    }
    return YES;
}
- (BOOL)loadFromInputStream:(BufferedInputStream *)is error:(NSError **)error {
    BOOL ret = NO;
    unsigned char *buf = (unsigned char *)malloc(HEADER_LENGTH);
    if (![is readExactly:HEADER_LENGTH into:buf error:error]) {
        goto load_error;
    }
    if (strncmp((const char *)buf, "XAttrSetV002", HEADER_LENGTH)) {
        SETNSERROR(@"XAttrSetErrorDomain", ERROR_INVALID_OBJECT_VERSION, @"invalid XAttrSet header");
        goto load_error;
    }
    uint64_t count;
    if (![IntegerIO readUInt64:&count from:is error:error]) {
        goto load_error;
    }
    for (uint64_t i = 0; i < count; i++) {
        NSString *name;
        if (![StringIO read:&name from:is error:error]) {
            goto load_error;
        }
        NSData *value;
        if (![DataIO read:&value from:is error:error]) {
            goto load_error;
        }
        [xattrs setObject:value forKey:name];
    }
    ret = YES;
load_error:
    free(buf);
    return ret;
}
@end
