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
#import "StandardRestoreWorker.h"
#import "StandardRestorer.h"
#import "Repo.h"
#import "StandardRestoreItem.h"
#import "StandardRestorerDelegate.h"
#import "Node.h"
#import "BlobKey.h"
#import "FileOutputStream.h"
#import "BufferedOutputStream.h"


@implementation StandardRestoreWorker
- (id)initWithStandardRestorer:(StandardRestorer *)theStandardRestorer standardRestorerDelegate:(id <StandardRestorerDelegate>)theSRD {
    if (self = [super init]) {
        standardRestorer = [theStandardRestorer retain];
        standardRestorerDelegate = theSRD;
        
        [self retain];
        [NSThread detachNewThreadSelector:@selector(run) toTarget:self withObject:nil];
    }
    return self;
}
- (void)dealloc {
    [standardRestorer release];
    [super dealloc];
}


- (void)run {
    NSAutoreleasePool *pool = nil;
    for (;;) {
        [pool drain];
        pool = [[NSAutoreleasePool alloc] init];
        
        StandardRestoreItem *item = [standardRestorer nextItem];
        if (item == nil) {
            break;
        }
        NSError *myError = nil;
        if (![item restore:&myError]) {
            [standardRestorerDelegate standardRestorerErrorMessage:[myError localizedDescription] didOccurForPath:[item path]];
        }
    }
    [standardRestorer workerDidFinish];
    [pool drain];
    
    [self release];
}
@end
