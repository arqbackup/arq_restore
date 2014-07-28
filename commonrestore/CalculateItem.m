//
//  CalculateItem.m
//  Arq
//
//  Created by Stefan Reitshamer on 6/10/13.
//  Copyright (c) 2013 Stefan Reitshamer. All rights reserved.
//

#import "CalculateItem.h"
#import "Tree.h"
#import "Node.h"
#import "Repo.h"
#import "BlobKey.h"
#import "FileInputStream.h"
#import "BufferedInputStream.h"
#import "NSData-GZip.h"
#import "SHA1Hash.h"
#import "Restorer.h"


@implementation CalculateItem
- (id)initWithPath:(NSString *)thePath tree:(Tree *)theTree {
    if (self = [super init]) {
        path = [thePath retain];
        tree = [theTree retain];
        filesToSkip = [[NSMutableSet alloc] init];
        nextItems = [[NSMutableArray alloc] init];
    }
    return self;
}
- (id)initWithPath:(NSString *)thePath node:(Node *)theNode {
    if (self = [super init]) {
        path = [thePath retain];
        node = [theNode retain];
        filesToSkip = [[NSMutableSet alloc] init];
        nextItems = [[NSMutableArray alloc] init];
    }
    return self;
}
- (void)dealloc {
    [path release];
    [node release];
    [filesToSkip release];
    [nextItems release];
    [super dealloc];
}

- (BOOL)calculateWithRepo:(Repo *)theRepo restorer:(id <Restorer>)theRestorer error:(NSError **)error {
    if (tree != nil) {
        if (![self addBlobKeyToBytesToTransfer:[tree xattrsBlobKey] restorer:theRestorer error:error]) {
            return NO;
        }
        if (![self addBlobKeyToBytesToTransfer:[tree aclBlobKey] restorer:theRestorer error:error]) {
            return NO;
        }
        for (NSString *childNodeName in [tree childNodeNames]) {
            Node *childNode = [tree childNodeWithName:childNodeName];
            NSString *childPath = [path stringByAppendingPathComponent:childNodeName];
            [nextItems addObject:[[[CalculateItem alloc] initWithPath:childPath node:childNode] autorelease]];
        }
    } else {
        NSAssert(node != nil, @"node can't be nil if tree is nil");
        if ([node isTree]) {
            Tree *childTree = [theRepo treeForBlobKey:[node treeBlobKey] error:error];
            if (childTree == nil) {
                return NO;
            }
            [nextItems addObject:[[[CalculateItem alloc] initWithPath:path tree:childTree] autorelease]];
        } else {
            if (![self addBlobKeyToBytesToTransfer:[node xattrsBlobKey] restorer:theRestorer error:error]) {
                return NO;
            }
            if (![self addBlobKeyToBytesToTransfer:[node aclBlobKey] restorer:theRestorer error:error]) {
                return NO;
            }
            for (BlobKey *dataBlobKey in [node dataBlobKeys]) {
                if (![self addBlobKeyToBytesToTransfer:dataBlobKey restorer:theRestorer error:error]) {
                    return NO;
                }
            }
        }
    }
    return YES;
}
- (unsigned long long)bytesToTransfer {
    return bytesToTransfer;
}
- (NSSet *)filesToSkip {
    return filesToSkip;
}
- (NSArray *)nextItems {
    return nextItems;
}


#pragma mark internal
- (BOOL)addBlobKeyToBytesToTransfer:(BlobKey *)theBlobKey restorer:(id <Restorer>)theRestorer error:(NSError **)error {
    if (theBlobKey == nil) {
        return YES;
    }
    NSError *myError = nil;
    NSNumber *size = [theRestorer sizeOfBlob:theBlobKey error:&myError];
    if (size == nil) {
        SETERRORFROMMYERROR;
        if ([myError isErrorWithDomain:[theRestorer errorDomain] code:ERROR_NOT_FOUND]) {
            HSLogError(@"%@", [myError localizedDescription]);
            size = [NSNumber numberWithUnsignedLongLong:0];
        } else {
            return NO;
        }
    }
    bytesToTransfer += [size unsignedLongLongValue];
    return YES;
}
@end
