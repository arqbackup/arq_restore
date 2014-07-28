//
//  GlacierRequestItem.m
//  Arq
//
//  Created by Stefan Reitshamer on 5/30/13.
//  Copyright (c) 2013 Stefan Reitshamer. All rights reserved.
//

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
