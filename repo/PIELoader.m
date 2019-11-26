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



#import "PIELoader.h"
#import "PIELoaderWorker.h"


#define NUM_WORKER_THREADS (5)


@implementation PIELoader
- (id)initWithDelegate:(id <PIELoaderDelegate>)theDelegate packIds:(NSArray *)thePackIds fark:(Fark *)theFark storageType:(StorageType)theStorageType {
    if (self = [super init]) {
        workerThreadSemaphore = dispatch_semaphore_create(0);
        packIds = [thePackIds retain];
        fark = theFark;
        delegate = theDelegate;
        lock = [[NSLock alloc] init];
        [lock setName:@"PIELoader"];
        
        HSLogDetail(@"saving entries from %ld packs to database", [thePackIds count]);
        
        
        for (NSUInteger i = 0; i < NUM_WORKER_THREADS; i++) {
            [[[PIELoaderWorker alloc] initWithPIELoader:self fark:fark storageType:theStorageType] autorelease];
        }
    }
    return self;
}
- (void)dealloc {
    [loadError release];
    [packIds release];
    [lock release];
    dispatch_release(workerThreadSemaphore);
    [super dealloc];
}
- (BOOL)waitForCompletion:(NSError **)error {
    for (NSUInteger i = 0; i < NUM_WORKER_THREADS; i++) {
        dispatch_semaphore_wait(workerThreadSemaphore, DISPATCH_TIME_FOREVER);
    }
    if (loadErrorOccurred) {
        if (error != NULL) {
            *error = loadError;
        }
        return NO;
    }
    return YES;
}
- (PackId *)nextPackId {
    PackId *ret = nil;
    [lock lock];
    if (!loadErrorOccurred) {
        if (packIdIndex < [packIds count]) {
            ret = [packIds objectAtIndex:packIdIndex];
            packIdIndex++;
        }
    }
    [lock unlock];
    return ret;
}
- (void)packIndexEntries:(NSArray *)thePIES wereLoadedForPackId:(PackId *)thePackId {
    [lock lock];
    loadedCount++;
    if (![delegate pieLoaderDidLoadPackIndexEntries:thePIES forPackId:thePackId index:loadedCount total:[packIds count] error:&loadError]) {
        loadErrorOccurred = YES;
        [loadError retain];
    }
    [lock unlock];
}
- (void)errorDidOccur:(NSError *)theError {
    [lock lock];
    loadErrorOccurred = YES;
    loadError = [theError retain];
    HSLogError(@"PIELoader: load error occurred: %@", loadError);
    [lock unlock];
}
- (void)workerDidFinish {
    dispatch_semaphore_signal(workerThreadSemaphore);
}
@end
