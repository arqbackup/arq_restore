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

#import "SFTPRemoteFS.h"
#import "Target.h"
#import "SFTPServer.h"
#import "NSString_extra.h"
#import "NSError_extra.h"
#import "TargetConnection.h"

#define INITIAL_RETRY_SLEEP (0.5)
#define RETRY_SLEEP_GROWTH_FACTOR (1.5)
#define MAX_RETRY_SLEEP (5.0)


@implementation SFTPRemoteFS
- (id)initWithTarget:(Target *)theTarget tempDir:(NSString *)theTempDir {
    if (self = [super init]) {
        target = [theTarget retain];
        tempDir = [theTempDir retain];
    }
    return self;
}
- (void)dealloc {
    [target release];
    [tempDir release];
    [sftpServer release];
    [super dealloc];
}

- (BOOL)renameObjectAtPath:(NSString *)theSource toPath:(NSString *)theDest targetConnectionDelegate:(id <TargetConnectionDelegate>)theTargetConnectionDelegate error:(NSError **)error {
    sleepTime = INITIAL_RETRY_SLEEP;
    BOOL ret = nil;
    NSAutoreleasePool *pool = nil;
    NSError *myError = nil;
    for (;;) {
        [pool drain];
        pool = [[NSAutoreleasePool alloc] init];
        myError = nil;
        
        if (![self connectWithTargetConnectionDelegate:theTargetConnectionDelegate error:&myError]) {
            break;
        }
        
        ret = [sftpServer ensureParentPathExistsForPath:theDest error:&myError]
        && [sftpServer removeItemAtPath:theDest error:&myError]
        && [sftpServer renameItemAtPath:theSource toPath:theDest error:&myError];
        if (ret) {
            break;
        }
        if (![theTargetConnectionDelegate targetConnectionShouldRetryOnTransientError:&myError]) {
            break;
        }
        if (![myError isTransientError]) {
            break;
        }
        
        HSLogDetail(@"SFTP error (retrying): %@", myError);
        [self disconnect];
        [self sleepBeforeRetry];
    }
    [myError retain];
    [pool drain];
    [myError autorelease];
    if (!ret) {
        SETERRORFROMMYERROR;
    }
    return ret;
}


#pragma mark RemoteFS
- (NSString *)errorDomain {
    return @"RemoteFSErrorDomain";
}
- (NSNumber *)fileExistsAtPath:(NSString *)thePath isDirectory:(BOOL *)isDirectory targetConnectionDelegate:(id <TargetConnectionDelegate>)theTargetConnectionDelegate error:(NSError **)error {
    sleepTime = INITIAL_RETRY_SLEEP;
    NSNumber *ret = nil;
    NSAutoreleasePool *pool = nil;
    NSError *myError = nil;
    for (;;) {
        [pool drain];
        pool = [[NSAutoreleasePool alloc] init];
        myError = nil;

        if (![self connectWithTargetConnectionDelegate:theTargetConnectionDelegate error:&myError]) {
            break;
        }
        
        ret = [sftpServer fileExistsAtPath:thePath isDirectory:isDirectory error:&myError];
        if (ret) {
            break;
        }
        if (![theTargetConnectionDelegate targetConnectionShouldRetryOnTransientError:&myError]) {
            break;
        }
        if (![myError isTransientError]) {
            break;
        }
        
        HSLogDetail(@"SFTP error (retrying): %@", myError);
        [self disconnect];
        [self sleepBeforeRetry];
    }
    [ret retain];
    [myError retain];
    [pool drain];
    [ret autorelease];
    [myError autorelease];
    if (ret == nil) {
        SETERRORFROMMYERROR;
    }
    return ret;
}
- (NSNumber *)fileExistsAtPath:(NSString *)thePath dataSize:(unsigned long long *)theDataSize targetConnectionDelegate:(id <TargetConnectionDelegate>)theTargetConnectionDelegate error:(NSError **)error {
    sleepTime = INITIAL_RETRY_SLEEP;
    NSNumber *ret = nil;
    NSAutoreleasePool *pool = nil;
    NSError *myError = nil;
    for (;;) {
        [pool drain];
        pool = [[NSAutoreleasePool alloc] init];
        myError = nil;

        if (![self connectWithTargetConnectionDelegate:theTargetConnectionDelegate error:&myError]) {
            break;
        }
        
        ret = [sftpServer fileExistsAtPath:thePath dataSize:theDataSize error:&myError];
        if (ret) {
            break;
        }
        if (![theTargetConnectionDelegate targetConnectionShouldRetryOnTransientError:&myError]) {
            break;
        }
        if (![myError isTransientError]) {
            break;
        }

        HSLogDetail(@"SFTP error (retrying): %@", myError);
        [self disconnect];
        [self sleepBeforeRetry];
    }
    [ret retain];
    [myError retain];
    [pool drain];
    [ret autorelease];
    [myError autorelease];
    if (ret == nil) {
        SETERRORFROMMYERROR;
    }
    return ret;
}
- (NSArray *)contentsOfDirectoryAtPath:(NSString *)thePath targetConnectionDelegate:(id <TargetConnectionDelegate>)theTargetConnectionDelegate error:(NSError **)error {
    sleepTime = INITIAL_RETRY_SLEEP;
    NSArray *ret = nil;
    NSAutoreleasePool *pool = nil;
    NSError *myError = nil;
    for (;;) {
        [pool drain];
        pool = [[NSAutoreleasePool alloc] init];
        myError = nil;

        if (![self connectWithTargetConnectionDelegate:theTargetConnectionDelegate error:&myError]) {
            break;
        }
        
        ret = [sftpServer contentsOfDirectoryAtPath:thePath error:&myError];
        if (ret) {
            break;
        }
        if (![theTargetConnectionDelegate targetConnectionShouldRetryOnTransientError:&myError]) {
            break;
        }
        if (![myError isTransientError]) {
            break;
        }
 
        HSLogDetail(@"SFTP error (retrying): %@", myError);
        [self disconnect];
        [self sleepBeforeRetry];
    }
    [ret retain];
    [myError retain];
    [pool drain];
    [ret autorelease];
    [myError autorelease];
    if (ret == nil) {
        SETERRORFROMMYERROR;
    }
    return ret;
}
- (NSData *)contentsOfFileAtPath:(NSString *)thePath dataTransferDelegate:(id<DataTransferDelegate>)theDTD targetConnectionDelegate:(id<TargetConnectionDelegate>)theTCD error:(NSError **)error {
    sleepTime = INITIAL_RETRY_SLEEP;
    NSData *ret = nil;
    NSAutoreleasePool *pool = nil;
    NSError *myError = nil;
    for (;;) {
        [pool drain];
        pool = [[NSAutoreleasePool alloc] init];
        myError = nil;

        if (![self connectWithTargetConnectionDelegate:theTCD error:&myError]) {
            break;
        }
        
        ret = [sftpServer contentsOfFileAtPath:thePath dataTransferDelegate:theDTD error:&myError];
        if (ret) {
            break;
        }
        if (![theTCD targetConnectionShouldRetryOnTransientError:&myError]) {
            break;
        }
        if (![myError isTransientError]) {
            break;
        }

        HSLogDetail(@"SFTP error (retrying): %@", myError);
        [self disconnect];
        [self sleepBeforeRetry];
    }
    [ret retain];
    [myError retain];
    [pool drain];
    [ret autorelease];
    [myError autorelease];
    if (ret == nil) {
        SETERRORFROMMYERROR;
    }
    return ret;
}
- (BOOL)writeData:(NSData *)theData atomicallyToFileAtPath:(NSString *)thePath dataTransferDelegate:(id<DataTransferDelegate>)theDTD targetConnectionDelegate:(id<TargetConnectionDelegate>)theTCD error:(NSError **)error {
    sleepTime = INITIAL_RETRY_SLEEP;
    NSString *tempPath = [tempDir stringByAppendingPathComponent:[NSString stringWithRandomUUID]];
    BOOL ret = nil;
    NSAutoreleasePool *pool = nil;
    NSError *myError = nil;
    for (;;) {
        [pool drain];
        pool = [[NSAutoreleasePool alloc] init];
        myError = nil;

        if (![self connectWithTargetConnectionDelegate:theTCD error:&myError]) {
            break;
        }
        
        ret = [sftpServer writeData:theData toFileAtPath:tempPath dataTransferDelegate:theDTD error:&myError]
        && [sftpServer ensureParentPathExistsForPath:thePath error:&myError]
        && [sftpServer removeItemAtPath:thePath error:&myError]
        && [sftpServer renameItemAtPath:tempPath toPath:thePath error:&myError];
        if (ret) {
            break;
        }
        if (![theTCD targetConnectionShouldRetryOnTransientError:&myError]) {
            break;
        }
        if (![myError isTransientError]) {
            break;
        }

        HSLogDetail(@"SFTP error (retrying): %@", myError);
        [self disconnect];
        [self sleepBeforeRetry];
    }
    [myError retain];
    [pool drain];
    [myError autorelease];
    if (!ret) {
        SETERRORFROMMYERROR;
    }
    return ret;
}
- (BOOL)removeItemAtPath:(NSString *)thePath targetConnectionDelegate:(id <TargetConnectionDelegate>)theTargetConnectionDelegate error:(NSError **)error {
    sleepTime = INITIAL_RETRY_SLEEP;
    BOOL ret = nil;
    NSAutoreleasePool *pool = nil;
    NSError *myError = nil;
    for (;;) {
        [pool drain];
        pool = [[NSAutoreleasePool alloc] init];
        myError = nil;

        if (![self connectWithTargetConnectionDelegate:theTargetConnectionDelegate error:&myError]) {
            break;
        }
        
        ret = [sftpServer removeItemAtPath:thePath error:&myError];
        if (ret) {
            break;
        }
        if (![theTargetConnectionDelegate targetConnectionShouldRetryOnTransientError:&myError]) {
            break;
        }
        if (![myError isTransientError]) {
            break;
        }
        
        HSLogDetail(@"SFTP error (retrying): %@", myError);
        [self disconnect];
        [self sleepBeforeRetry];
    }
    [myError retain];
    [pool drain];
    [myError autorelease];
    if (!ret) {
        SETERRORFROMMYERROR;
    }
    return ret;
}
- (BOOL)createDirectoryAtPath:(NSString *)thePath withIntermediateDirectories:(BOOL)createIntermediates targetConnectionDelegate:(id <TargetConnectionDelegate>)theTargetConnectionDelegate error:(NSError **)error {
    sleepTime = INITIAL_RETRY_SLEEP;
    BOOL ret = nil;
    NSAutoreleasePool *pool = nil;
    NSError *myError = nil;
    for (;;) {
        [pool drain];
        pool = [[NSAutoreleasePool alloc] init];
        myError = nil;

        if (![self connectWithTargetConnectionDelegate:theTargetConnectionDelegate error:&myError]) {
            break;
        }
        
        ret = [sftpServer createDirectoryAtPath:thePath withIntermediateDirectories:createIntermediates error:&myError];
        if (ret) {
            break;
        }
        if (![theTargetConnectionDelegate targetConnectionShouldRetryOnTransientError:&myError]) {
            break;
        }
        if (![myError isTransientError]) {
            break;
        }
        
        HSLogDetail(@"SFTP error (retrying): %@", myError);
        [self disconnect];
        [self sleepBeforeRetry];
    }
    [myError retain];
    [pool drain];
    [myError autorelease];
    if (!ret) {
        SETERRORFROMMYERROR;
    }
    return ret;
}
- (NSNumber *)sizeOfItemAtPath:(NSString *)thePath targetConnectionDelegate:(id <TargetConnectionDelegate>)theTargetConnectionDelegate error:(NSError **)error {
    sleepTime = INITIAL_RETRY_SLEEP;
    NSNumber *ret = nil;
    NSAutoreleasePool *pool = nil;
    NSError *myError = nil;
    for (;;) {
        [pool drain];
        pool = [[NSAutoreleasePool alloc] init];
        myError = nil;

        if (![self connectWithTargetConnectionDelegate:theTargetConnectionDelegate error:&myError]) {
            break;
        }
        
        ret = [sftpServer sizeOfItemAtPath:thePath error:&myError];
        if (ret) {
            break;
        }
        if (![theTargetConnectionDelegate targetConnectionShouldRetryOnTransientError:&myError]) {
            break;
        }
        if (![myError isTransientError]) {
            break;
        }
        
        HSLogDetail(@"SFTP error (retrying): %@", myError);
        [self disconnect];
        [self sleepBeforeRetry];
    }
    [ret retain];
    [myError retain];
    [pool drain];
    [ret autorelease];
    [myError autorelease];
    if (ret == nil) {
        SETERRORFROMMYERROR;
    }
    return ret;
}
- (NSArray *)objectsAtPath:(NSString *)thePath targetConnectionDelegate:(id <TargetConnectionDelegate>)theTargetConnectionDelegate error:(NSError **)error {
    sleepTime = INITIAL_RETRY_SLEEP;
    NSArray *ret = nil;
    NSAutoreleasePool *pool = nil;
    NSError *myError = nil;
    for (;;) {
        [pool drain];
        pool = [[NSAutoreleasePool alloc] init];
        myError = nil;

        if (![self connectWithTargetConnectionDelegate:theTargetConnectionDelegate error:&myError]) {
            break;
        }
        
        ret = [sftpServer objectsAtPath:thePath error:&myError];
        if (ret) {
            break;
        }
        if (![theTargetConnectionDelegate targetConnectionShouldRetryOnTransientError:&myError]) {
            break;
        }
        if (![myError isTransientError]) {
            break;
        }
        
        HSLogDetail(@"SFTP error (retrying): %@", myError);
        [self disconnect];
        [self sleepBeforeRetry];
    }
    [ret retain];
    [myError retain];
    [pool drain];
    [ret autorelease];
    [myError autorelease];
    if (ret == nil) {
        SETERRORFROMMYERROR;
    }
    return ret;
}
- (NSArray *)pathsOfObjectsAtPath:(NSString *)thePath targetConnectionDelegate:(id <TargetConnectionDelegate>)theTargetConnectionDelegate error:(NSError **)error {
    sleepTime = INITIAL_RETRY_SLEEP;
    NSArray *ret = nil;
    NSAutoreleasePool *pool = nil;
    NSError *myError = nil;
    for (;;) {
        [pool drain];
        pool = [[NSAutoreleasePool alloc] init];
        myError = nil;

        if (![self connectWithTargetConnectionDelegate:theTargetConnectionDelegate error:&myError]) {
            break;
        }
        
        ret = [sftpServer pathsOfObjectsAtPath:thePath error:&myError];
        if (ret) {
            break;
        }
        if (![theTargetConnectionDelegate targetConnectionShouldRetryOnTransientError:&myError]) {
            break;
        }
        if (![myError isTransientError]) {
            break;
        }
        
        HSLogDetail(@"SFTP error (retrying): %@", myError);
        [self disconnect];
        [self sleepBeforeRetry];
    }
    [ret retain];
    [myError retain];
    [pool drain];
    [ret autorelease];
    [myError autorelease];
    if (ret == nil) {
        SETERRORFROMMYERROR;
    }
    return ret;
}
- (NSNumber *)isObjectRestoredAtPath:(NSString *)thePath targetConnectionDelegate:(id <TargetConnectionDelegate>)theTargetConnectionDelegate error:(NSError **)error {
    SETNSERROR([self errorDomain], -1, @"isObjectRestoredAtPath is not supported by SFTPRemoteFS");
    return nil;
}
- (BOOL)restoreObjectAtPath:(NSString *)thePath forDays:(NSUInteger)theDays alreadyRestoredOrRestoring:(BOOL *)alreadyRestoredOrRestoring targetConnectionDelegate:(id <TargetConnectionDelegate>)theTargetConnectionDelegate error:(NSError **)error {
    SETNSERROR([self errorDomain], -1, @"restoreObjectAtPath is not supported by SFTPRemoteFS");
    return NO;
}


#pragma mark internal
- (BOOL)connectWithTargetConnectionDelegate:(id <TargetConnectionDelegate>)theTargetConnectionDelegate error:(NSError **)error {
    sleepTime = INITIAL_RETRY_SLEEP;
    BOOL ret = YES;
    NSAutoreleasePool *pool = nil;
    NSError *myError = nil;
    for (;;) {
        [pool drain];
        pool = [[NSAutoreleasePool alloc] init];
        myError = nil;
        
        ret = [self connect:&myError];
        if (ret) {
            break;
        }
        if (![theTargetConnectionDelegate targetConnectionShouldRetryOnTransientError:&myError]) {
            break;
        }
        if (![myError isTransientError]) {
            break;
        }
        
        HSLogDetail(@"SFTP error (retrying): %@", myError);
        [self sleepBeforeRetry];
    }
    [myError retain];
    [pool drain];
    [myError autorelease];
    if (!ret) {
        SETERRORFROMMYERROR;
    }
    return ret;
}
- (BOOL)connect:(NSError **)error {
    if (sftpServer == nil) {
        NSString *secret = [target secret:error];
        if (secret == nil) {
            return NO;
        }
        
        NSString *privateKeyPath = nil;
        NSString *password = nil;
        NSString *passphrase = nil;
        if ([[NSFileManager defaultManager] fileExistsAtPath:[secret stringByExpandingTildeInPath]]) {
            privateKeyPath = [secret stringByExpandingTildeInPath];
        } else {
            password = secret;
        }
        
        NSError *myError = nil;
        passphrase = [target passphrase:&myError];
        if (passphrase == nil) {
            if ([myError code] != ERROR_NOT_FOUND) {
                SETERRORFROMMYERROR;
                return NO;
            }
        }
        sftpServer = [[SFTPServer alloc] initWithURL:[target endpoint] password:password privateKeyPath:privateKeyPath passphrase:passphrase error:error];
        if (sftpServer == nil) {
            return NO;
        }
    }
    return YES;
}
- (void)disconnect {
    [sftpServer release];
    sftpServer = nil;
}
- (void)sleepBeforeRetry {
    HSLogDebug(@"sleeping for %0.1f seconds", sleepTime);
    [NSThread sleepForTimeInterval:sleepTime];
    sleepTime *= RETRY_SLEEP_GROWTH_FACTOR;
    if (sleepTime > MAX_RETRY_SLEEP) {
        sleepTime = MAX_RETRY_SLEEP;
    }
}
@end
