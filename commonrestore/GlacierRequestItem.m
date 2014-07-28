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


#import "GlacierRequestItem.h"
#import "Tree.h"
#import "Node.h"
#import "GlacierRestorer.h"
#import "BlobKey.h"
#import "Repo.h"


@implementation GlacierRequestItem
- (id)initWithPath:(NSString *)thePath tree:(Tree *)theTree {
    if (self = [super init]) {
        path = [thePath retain];
        tree = [theTree retain];
    }
    return self;
}
- (id)initWithPath:(NSString *)thePath node:(Node *)theNode {
    if (self = [super init]) {
        path = [thePath retain];
        node = [theNode retain];
    }
    return self;
}
- (id)initWithPath:(NSString *)thePath node:(Node *)theNode dataBlobKeyIndex:(NSUInteger)theDataBlobKeyIndex {
    if (self = [super init]) {
        path = [thePath retain];
        node = [theNode retain];
        dataBlobKeyIndex = theDataBlobKeyIndex;
        NSAssert(theDataBlobKeyIndex > 0, @"theDataBlobKeyIndex must be > 0");
        requestedFirstBlobKey = YES;
    }
    return self;
}
- (void)dealloc {
    [path release];
    [tree release];
    [node release];
    [super dealloc];
}

- (NSArray *)requestWithRestorer:(id <Restorer>)theRestorer repo:(Repo *)theRepo error:(NSError **)error {
    NSMutableArray *nextItems = [NSMutableArray array];

    if (tree != nil) {
        if (![theRestorer requestBlobKey:[tree xattrsBlobKey] error:error]) {
            return nil;
        }
        if (![theRestorer requestBlobKey:[tree aclBlobKey] error:error]) {
            return nil;
        }
        for (NSString *childNodeName in [tree childNodeNames]) {
            Node *childNode = [tree childNodeWithName:childNodeName];
            NSString *childPath = [path stringByAppendingPathComponent:childNodeName];
            [nextItems addObject:[[[GlacierRequestItem alloc] initWithPath:childPath node:childNode] autorelease]];
        }
    } else {
        NSAssert(node != nil, @"node can't be nil if tree is nil");
        if ([node isTree]) {
            Tree *childTree = [theRepo treeForBlobKey:[node treeBlobKey] error:error];
            if (childTree == nil) {
                return nil;
            }
            [nextItems addObject:[[[GlacierRequestItem alloc] initWithPath:path tree:childTree] autorelease]];
        } else {
            if (!requestedFirstBlobKey) {
                if (![theRestorer requestBlobKey:[node xattrsBlobKey] error:error]) {
                    return nil;
                }
                if (![theRestorer requestBlobKey:[node aclBlobKey] error:error]) {
                    return nil;
                }
                if (![theRestorer shouldSkipFile:path]) {
                    if ([[node dataBlobKeys] count] > 0) {
                        BlobKey *firstKey = [[node dataBlobKeys] objectAtIndex:0];
                        HSLogDetail(@"requesting first data blob of %ld for %@", (unsigned long)[[node dataBlobKeys] count], path);
                        if (![theRestorer requestBlobKey:firstKey error:error]) {
                            return nil;
                        }
                        if ([[node dataBlobKeys] count] > 1) {
                            [nextItems addObject:[[[GlacierRequestItem alloc] initWithPath:path node:node dataBlobKeyIndex:1] autorelease]];
                        }
                    }
                }
            } else {
                BlobKey *blobKey = [[node dataBlobKeys] objectAtIndex:dataBlobKeyIndex];
                HSLogDetail(@"requesting data blob %ld of %ld for %@", (unsigned long)(dataBlobKeyIndex + 1), (unsigned long)[[node dataBlobKeys] count], path);
                if (![theRestorer requestBlobKey:blobKey error:error]) {
                    return nil;
                }
                if ([[node dataBlobKeys] count] > (dataBlobKeyIndex + 1)) {
                    [nextItems addObject:[[[GlacierRequestItem alloc] initWithPath:path node:node dataBlobKeyIndex:(dataBlobKeyIndex + 1)] autorelease]];
                }
            }
        }
    }
    return nextItems;
}
@end
