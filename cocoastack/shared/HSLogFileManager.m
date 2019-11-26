/*
 Copyright (c) 2009-2017, Haystack Software LLC https://www.arqbackup.com
 
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
#import "HSLogFileManager.h"
#import "CacheOwnership.h"

#define LOG_FILE_MODE (0666)


@implementation HSLogFileManager

- (NSString *)errorDomain {
    return @"HSLogFileManagerErrorDomain";
}

- (NSString *)createNewLogFile {
    NSString *path = [super createNewLogFile];
    if (path != nil) {
        NSError *myError = nil;
        if (![self setPermissionsOnLogFile:path error:&myError]) {
            NSLog(@"%@", myError);
        }
    }
    return path;
}
- (BOOL)setPermissionsOnLogFile:(NSString *)thePath error:(NSError **)error {
    struct stat st;
    if (lstat([thePath fileSystemRepresentation], &st) < 0) {
        int errnum = errno;
        SETNSERROR([self errorDomain], -1, @"failed to stat %@: %s", thePath, strerror(errnum));
        return NO;
    }
    
    uid_t theUID = [[CacheOwnership sharedCacheOwnership] uid];
    gid_t theGID = [[CacheOwnership sharedCacheOwnership] gid];
    if (st.st_uid != theUID || st.st_gid != theGID) {
        NSLog(@"setting log file ownership to %d:%d for %@", theUID, theGID, thePath);
        if (chown([thePath fileSystemRepresentation], theUID, theGID) < 0) {
            int errnum = errno;
            SETNSERROR([self errorDomain], -1, @"failed to set ownership of %@: %s", thePath, strerror(errnum));
            return NO;
        }
    }
    if (st.st_mode != LOG_FILE_MODE) {
        NSLog(@"setting log file permissions to %o for %@", LOG_FILE_MODE, thePath);
        if (chmod([thePath fileSystemRepresentation], LOG_FILE_MODE) < 0) {
            int errnum = errno;
            SETNSERROR([self errorDomain], -1, @"failed to set permissions on %@: %s", thePath, strerror(errnum));
            return NO;
        }
    }
    return YES;
}

// Notifications from DDFileLogger
- (void)didArchiveLogFile:(NSString *)logFilePath {
    
}
- (void)didRollAndArchiveLogFile:(NSString *)logFilePath {
    
}
@end
