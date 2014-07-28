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
#include <stdio.h>
#import "FileACL.h"

#import "NSError_extra.h"

@implementation FileACL
+ (BOOL)aclText:(NSString **)aclText forFile:(NSString *)path error:(NSError **)error {
    *aclText = nil;
    const char *pathChars = [path fileSystemRepresentation];
    acl_t acl = acl_get_link_np(pathChars, ACL_TYPE_EXTENDED);
    if (!acl) {
        if (errno != ENOENT) {
            int errnum = errno;
            HSLogError(@"acl_get_link_np(%@) error %d: %s", path, errnum, strerror(errnum));
            SETNSERROR(@"UnixErrorDomain", errnum, @"failed to get ACL of %@: %s", path, strerror(errnum));
            return NO;
        }
    } else {
        char *aclTextChars = acl_to_text(acl, NULL);
        if (!aclTextChars) {
            acl_free(acl);
            int errnum = errno;
            HSLogError(@"acl_to_text from %@ error %d: %s", path, errnum, strerror(errnum));
            SETNSERROR(@"UnixErrorDomain", errnum, @"failed to convert ACL of %@ to text: %s", path, strerror(errnum));
            return NO;
        }
        *aclText = [NSString stringWithUTF8String:aclTextChars];
        acl_free(aclTextChars);
        acl_free(acl);
    }
    return YES;
}
+ (BOOL)writeACLText:(NSString *)aclText toFile:(NSString *)path error:(NSError **)error {
    HSLogTrace(@"applying ACL %@ to %@", aclText, path);
    const char *pathChars = [path fileSystemRepresentation];
    acl_t acl = acl_from_text([aclText UTF8String]);
    if (!acl) {
        int errnum = errno;
        HSLogError(@"acl_from_text(%@) error %d: %s", aclText, errnum, strerror(errnum));
        SETNSERROR(@"UnixErrorDomain", errnum,  @"failed to convert ACL text '%@' to ACL: %s", aclText, strerror(errnum));
        return NO;
    }
    
    BOOL ret = NO;
    struct stat st;
    if (lstat(pathChars, &st) == -1) {
        int errnum = errno;
        HSLogError(@"lstat(%@) error %d: %s", path, errnum, strerror(errnum));
        SETNSERROR(@"UnixErrorDomain", errnum, @"%@: %s", path, strerror(errnum));
        goto writeACLText_error;
    }
    if (S_ISLNK(st.st_mode)) {
        ret = acl_set_link_np(pathChars, ACL_TYPE_EXTENDED, acl) != -1;
    } else {
        ret = acl_set_file(pathChars, ACL_TYPE_EXTENDED, acl) != -1;
    }
    if (!ret) {
        int errnum = errno;
        HSLogError(@"acl_set(%@) error %d: %s", path, errnum, strerror(errnum));
        SETNSERROR(@"UnixErrorDomain", errnum, @"failed to set ACL '%@' on %@: %s", aclText, path, strerror(errnum));
        goto writeACLText_error;
    }
    ret = YES;
writeACLText_error:
    acl_free(acl);
    return ret;
}
@end
