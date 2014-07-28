//
//  GlacierRequestItem.h
//  Arq
//
//  Created by Stefan Reitshamer on 5/30/13.
//  Copyright (c) 2013 Stefan Reitshamer. All rights reserved.
//

@class Tree;
@class Node;
@protocol Restorer;
@class Repo;


@interface GlacierRequestItem : NSObject {
    Tree *tree;
    Node *node;
    NSString *path;
    BOOL requestedFirstBlobKey;
    NSUInteger dataBlobKeyIndex;
}
- (id)initWithPath:(NSString *)thePath tree:(Tree *)theTree;
- (id)initWithPath:(NSString *)thePath node:(Node *)theNode;

- (NSArray *)requestWithRestorer:(id <Restorer>)theRestorer repo:(Repo *)theRepo error:(NSError **)error;
@end
