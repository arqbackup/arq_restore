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
