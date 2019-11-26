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



#include <sys/types.h>
#include <sys/stat.h>
#include <string.h>
#import "FlockFile.h"
#import "CacheOwnership.h"
#import "NSFileManager_extra.h"

@implementation FlockFile
- (id)init {
    @throw [NSException exceptionWithName:@"InvalidInitializerException" reason:@"don't call this init method on FlockFile" userInfo:[NSDictionary dictionary]];
}
- (id)initWithPath:(NSString *)thePath {
    if (self = [super init]) {
        path = [thePath retain];
        fd = -1;
        
    }
    return self;
}
- (void)dealloc {
    [path release];
    if (fd >= 0) {
        close(fd);
    }
    [super dealloc];
}
- (BOOL)tryLock:(NSError **)error {
    return [self lockWithBlockUntilAvailable:NO error:error];
}
- (BOOL)lockAndExecute:(void (^)(void))block error:(NSError **)error {
    if (![self lockWithBlockUntilAvailable:YES error:error]) {
        return NO;
    }
    block();
    if (![self unlock:error]) {
        return NO;
    }
    close(fd);
    fd = -1;
    return YES;
}


#pragma mark internal
- (BOOL)lockWithBlockUntilAvailable:(BOOL)blockUntilAvailable error:(NSError **)error {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    BOOL ret = [self doLockWithBlockUntilAvailable:blockUntilAvailable error:error];
    if (!ret && error != NULL) {
        [*error retain];
    }
    [pool drain];
    if (!ret && error != NULL) {
        [*error autorelease];
    }
    return ret;
}
- (BOOL)doLockWithBlockUntilAvailable:(BOOL)blockUntilAvailable error:(NSError **)error {
    if (![[NSFileManager defaultManager] ensureParentPathExistsForPath:path targetUID:[[CacheOwnership sharedCacheOwnership] uid] targetGID:[[CacheOwnership sharedCacheOwnership] gid] error:error]) {
        return NO;
    }
    fd = open([path fileSystemRepresentation], O_RDONLY|O_CREAT, S_IRWXU|S_IRWXG|S_IRWXO);
    if (fd == -1) {
        int errnum = errno;
        HSLogError(@"open(%@) error %d: %s", path, errnum, strerror(errnum));
        SETNSERROR(@"UnixErrorDomain", errnum, @"failed to open lock file %@: %s", path, strerror(errnum));
        return NO;
    }
    if (chown([path fileSystemRepresentation], [[CacheOwnership sharedCacheOwnership] uid], [[CacheOwnership sharedCacheOwnership] gid]) == -1) {
        int errnum = errno;
        SETNSERROR(@"UnixErrorDomain", errnum, @"chown(%@, %d, %d): %s", path, [[CacheOwnership sharedCacheOwnership] uid], [[CacheOwnership sharedCacheOwnership] gid], strerror(errnum));
        return NO;
    }
    // Set the permissions again because it doesn't get the permissions we asked for with the open() call!?
    if (chmod([path fileSystemRepresentation], S_IRWXU|S_IRWXG|S_IRWXO) < 0) {
        int errnum = errno;
        HSLogError(@"chmod(%@) error %d: %s", path, errnum, strerror(errnum));
    }
    
    int options = LOCK_EX;
    if (!blockUntilAvailable) {
        options |= LOCK_NB;
    }
    if (flock(fd, options) == -1) {
        int errnum = errno;
        HSLogError(@"flock(%@) error %d: %s", path, errnum, strerror(errnum));
        if (errnum == EWOULDBLOCK) {
            SETNSERROR(@"FlockFileErrorDomain", FLOCK_FILE_IN_USE, @"failed to lock %@ because it was in use: %s", path, strerror(errnum));
        } else {
            SETNSERROR(@"UnixErrorDomain", errnum, @"failed to lock %@: %s", path, strerror(errnum));
        }
        return NO;
    }
    return YES;
}
- (BOOL)unlock:(NSError **)error {
    if (flock(fd, LOCK_UN) == -1) {
        int errnum = errno;
        HSLogError(@"failed to unlock %@: %s", path, strerror(errnum));
        return NO;
    }
    return YES;
}
@end
