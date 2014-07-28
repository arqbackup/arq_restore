//
//  CalculateItem.h
//  Arq
//
//  Created by Stefan Reitshamer on 6/10/13.
//  Copyright (c) 2013 Stefan Reitshamer. All rights reserved.
//

#include <sys/stat.h>
@class Tree;
@class Node;
@class Repo;
@protocol Restorer;


@interface CalculateItem : NSObject {
    NSString *path;
    Tree *tree;
    Node *node;
    struct stat st;
    unsigned long long bytesToTransfer;
    NSMutableSet *filesToSkip;
    NSMutableArray *nextItems;
}
- (id)initWithPath:(NSString *)thePath tree:(Tree *)theTree;
- (id)initWithPath:(NSString *)thePath node:(Node *)theNode;
- (BOOL)calculateWithRepo:(Repo *)theRepo restorer:(id <Restorer>)theRestorer error:(NSError **)error;
- (unsigned long long)bytesToTransfer;
- (NSSet *)filesToSkip;
- (NSArray *)nextItems;
@end
