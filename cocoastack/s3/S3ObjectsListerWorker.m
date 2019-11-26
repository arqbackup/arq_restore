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



#import "S3ObjectsListerWorker.h"
#import "S3ObjectsLister.h"
#import "S3AuthorizationProvider.h"
#import "S3Lister.h"


@implementation S3ObjectsListerWorker
- (id)initWithS3AuthorizationProvider:(id <S3AuthorizationProvider>)theSAP
                             endpoint:(NSURL *)theEndpoint
             targetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD
                      s3ObjectsLister:(S3ObjectsLister *)theS3ObjectsLister {
    if (self = [super init]) {
        sap = [theSAP retain];
        endpoint = [theEndpoint retain];
        targetConnectionDelegate = theTCD;
        s3ObjectsLister = [theS3ObjectsLister retain];
        
        [self retain];
        
        [NSThread detachNewThreadSelector:@selector(run) toTarget:self withObject:nil];
    }
    return self;
}
- (void)dealloc {
    [sap release];
    [endpoint release];
    [s3ObjectsLister release];
    [super dealloc];
}


- (void)run {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    for (;;) {
        NSString *prefix = [s3ObjectsLister nextPrefix];
        if (prefix == nil) {
            break;
        }
        NSError *myError = nil;
        S3Lister *lister = [[[S3Lister alloc] initWithS3AuthorizationProvider:sap endpoint:endpoint path:prefix delimiter:nil targetConnectionDelegate:targetConnectionDelegate] autorelease];
        NSDictionary *itemsByName = [lister itemsByName:&myError];
        if (itemsByName == nil) {
            [s3ObjectsLister workerDidFail:myError];
            break;
        } else {
            [s3ObjectsLister workerFoundItemsByName:itemsByName];
        }
    }
    [s3ObjectsLister workerDidFinish];
    [pool drain];
}

@end
