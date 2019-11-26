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



#import "RemoteFSFileDeleter.h"
#import "RemoteFS.h"
#import "TargetConnection.h"
#import "RemoteFSFileDeleterWorker.h"
#import "HTTPThrottle.h"
#import "DeleteDelegate.h"
#import "ItemsDB.h"


#define NUM_WORKER_THREADS (5)


@implementation RemoteFSFileDeleter
- (id)initWithRemoteFS:(RemoteFS *)theRemoteFS filePaths:(NSArray *)theFilePaths cacheUUID:(NSString *)theCacheUUID deleteDelegate:(id <DeleteDelegate>)theDD targetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD {
    if (self = [super init]) {
        remoteFS = [theRemoteFS retain];
        filePaths = [theFilePaths retain];
        cacheUUID = [theCacheUUID retain];
        deleteDelegate = theDD;
        targetConnectionDelegate = theTCD;
        workerThreadSemaphore = dispatch_semaphore_create(0);
        
        lock = [[NSLock alloc] init];
        [lock setName:@"RemoteFSFileDeleter lock"];
        
        HSLogDebug(@"deleting %ld file paths", [theFilePaths count]);
        
        HSLogDebug(@"creating %d worker threads", NUM_WORKER_THREADS);
        for (NSUInteger i = 0; i < NUM_WORKER_THREADS; i++) {
            [[[RemoteFSFileDeleterWorker alloc] initWithRemoteFSFileDeleter:self remoteFS:theRemoteFS targetConnectionDelegate:theTCD] autorelease];
        }
    }
    return self;
}
- (void)dealloc {
    [remoteFS release];
    [filePaths release];
    [cacheUUID release];
    if (workerThreadSemaphore) {
        dispatch_release(workerThreadSemaphore);
    }
    [lock release];
    [super dealloc];
}

- (void)waitForCompletion {
    for (NSUInteger i = 0; i < NUM_WORKER_THREADS; i++) {
        dispatch_semaphore_wait(workerThreadSemaphore, DISPATCH_TIME_FOREVER);
    }
    HSLogDebug(@"finished deleting %ld path%@", [filePaths count], ([filePaths count] == 1 ? @"" : @"s"));
    [deleteDelegate didFinishDeleting:[filePaths count]];
}

- (NSString *)nextPath {
    [lock lock];
    NSString *ret = nil;
    if (!errorOccurred) {
        if (filePathsIndex < [filePaths count]) {
            ret = [filePaths objectAtIndex:filePathsIndex];
            filePathsIndex++;
            NSError *myError = nil;
            if (deleteDelegate != nil && ![deleteDelegate didDelete:filePathsIndex ofTotal:[filePaths count] error:&myError]) {
                HSLogDebug(@"deleteDelegate returned error: %@", myError);
                HSLogError(@"%@", [myError localizedDescription]);
                ret = nil;
            }
        }
    }
    [lock unlock];
    return ret;
}
- (void)workerDidFinish {
    dispatch_semaphore_signal(workerThreadSemaphore);
}
@end
