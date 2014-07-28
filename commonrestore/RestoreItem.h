//
//  RestoreItem.h
//  Arq
//
//  Created by Stefan Reitshamer on 5/30/13.
//  Copyright (c) 2013 Stefan Reitshamer. All rights reserved.
//


@class Tree;
@class Node;
@class Repo;
@protocol Restorer;
@class FileOutputStream;


@interface RestoreItem : NSObject {
    Tree *tree;
    Node *node;
    NSString *path;
    int restoreAction;
    FileOutputStream *fileOutputStream;
    NSUInteger dataBlobKeyIndex;
    BOOL errorOccurred;
}
- (id)initWithPath:(NSString *)thePath tree:(Tree *)theTree;
- (id)initWithPath:(NSString *)thePath tree:(Tree *)theTree node:(Node *)theNode;
- (id)initWithPath:(NSString *)thePath tree:(Tree *)theTree node:(Node *)theNode fileOutputStream:(FileOutputStream *)theFileOutputStream dataBlobKeyIndex:(NSUInteger)theDataBlobKeyIndex;

- (NSString *)errorDomain;
- (NSString *)path;
- (BOOL)restoreWithHardlinks:(NSMutableDictionary *)theHardlinks restorer:(id <Restorer>)theRestorer error:(NSError **)error;
- (NSArray *)nextItemsWithRepo:(Repo *)theRepo error:(NSError **)error;
@end
