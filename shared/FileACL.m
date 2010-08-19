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

#include <sys/stat.h>
#include <stdio.h>
#import "FileACL.h"
#import "SetNSError.h"

@implementation FileACL
+ (BOOL)aclText:(NSString **)aclText forFile:(NSString *)path error:(NSError **)error {
    *aclText = nil;
    const char *pathChars = [path fileSystemRepresentation];
    acl_t acl = acl_get_link_np(pathChars, ACL_TYPE_EXTENDED);
    if (!acl) {
        if (errno != ENOENT) {
            SETNSERROR(@"UnixErrorDomain", errno, @"acl_get_link_np: %s", strerror(errno));
            return NO;
        }
    } else {
        char *aclTextChars = acl_to_text(acl, NULL);
        if (!aclTextChars) {
            acl_free(acl);
            SETNSERROR(@"UnixErrorDomain", errno, @"acl_to_text: %s", strerror(errno));
            return NO;
        }
        *aclText = [NSString stringWithUTF8String:aclTextChars];
        acl_free(aclTextChars);
        acl_free(acl);
    }
    return YES;
}
+ (BOOL)writeACLText:(NSString *)aclText toFile:(NSString *)path error:(NSError **)error {
    const char *pathChars = [path fileSystemRepresentation];
    acl_t acl = acl_from_text([aclText UTF8String]);
    if (!acl) {
        SETNSERROR(@"UnixErrorDomain", errno,  @"acl_from_text: %s", strerror(errno));
        return NO;
    }
    struct stat st;
    if (lstat(pathChars, &st) == -1) {
        SETNSERROR(@"UnixErrorDomain", errno, @"%s", strerror(errno));
        return NO;
    }
    int ret = 0;
    if (S_ISLNK(st.st_mode)) {
        ret = acl_set_link_np(pathChars, ACL_TYPE_EXTENDED, acl);
    } else {
        ret = acl_set_file(pathChars, ACL_TYPE_EXTENDED, acl);
    }
    if (ret == -1) {
        SETNSERROR(@"UnixErrorDomain", errno, @"acl_set: %s", strerror(errno));
        return NO;
    }
    return YES;
}
@end
