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



#import "S3ObjectsLister.h"
#import "S3AuthorizationProvider.h"
#import "NSString_extra.h"
#import "S3ObjectsListerWorker.h"
#import "Item.h"


#define NUM_WORKER_THREADS (6)


@implementation S3ObjectsLister
- (id)initWithS3AuthorizationProvider:(id <S3AuthorizationProvider>)theSAP
                             endpoint:(NSURL *)theEndpoint
                                 path:(NSString *)thePath
             targetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD {
    if (self = [super init]) {
        sap = [theSAP retain];
        endpoint = [theEndpoint retain];
		path = [thePath retain];
        targetConnectionDelegate = theTCD;

        workerThreadSemaphore = dispatch_semaphore_create(0);
        prefixes = [[NSMutableArray alloc] init];
        lock = [[NSLock alloc] init];
        [lock setName:@"S3ObjectsLister lock"];
        
        for (int i = 0; i < 256; i++) {
            unsigned char buf[1];
            buf[0] = (unsigned char)i;
            NSString *hexString = [NSString hexStringWithBytes:buf length:1];
            [prefixes addObject:[NSString stringWithFormat:@"%@%@", thePath, hexString]];
        }
        
        itemsByName = [[NSMutableDictionary alloc] init];
    }
    return self;
}
- (void)dealloc {
    [endpoint release];
	[sap release];
    dispatch_release(workerThreadSemaphore);
    [prefixes release];
    [lock release];
    [itemsByName release];
    [_error release];
	[super dealloc];
}
- (NSDictionary *)itemsByName:(NSError **)error {
    for (int i = 0; i < NUM_WORKER_THREADS; i++) {
        [[[S3ObjectsListerWorker alloc] initWithS3AuthorizationProvider:sap endpoint:endpoint targetConnectionDelegate:targetConnectionDelegate s3ObjectsLister:self] autorelease];
    }
    
    for (int i = 0; i < NUM_WORKER_THREADS; i++) {
        dispatch_semaphore_wait(workerThreadSemaphore, DISPATCH_TIME_FOREVER);
    }
    
    if (_error != nil) {
        if (error != NULL) {
            *error = [[_error retain] autorelease];
        }
        return nil;
    }
    
    return itemsByName;
}

- (NSString *)nextPrefix {
    [lock lock];
    NSString *ret = nil;
    if ([prefixes count] > 0) {
        ret = [[[prefixes lastObject] retain] autorelease];
        [prefixes removeLastObject];
    }
    [lock unlock];
    return ret;
}
- (void)workerDidFail:(NSError *)theError {
    [lock lock];
    [theError retain];
    [_error release];
    _error = theError;
    [lock unlock];
}
- (void)workerFoundItemsByName:(NSDictionary *)theItemsByName {
    [lock lock];
    for (NSString *name in [theItemsByName allKeys]) {
        [itemsByName setObject:[theItemsByName objectForKey:name] forKey:name];
    }
    [lock unlock];
}
- (void)workerDidFinish {
    dispatch_semaphore_signal(workerThreadSemaphore);
}
@end
