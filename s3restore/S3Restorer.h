//
//  S3Restorer.h
//  Arq
//
//  Created by Stefan Reitshamer on 5/28/13.
//  Copyright (c) 2013 Stefan Reitshamer. All rights reserved.
//

#import "StorageType.h"
#import "Restorer.h"
#import "TargetConnection.h"
@protocol S3RestorerDelegate;
@class S3RestorerParamSet;
@class Repo;
@class Commit;
@class Tree;
@class BlobKey;


@interface S3Restorer : NSObject <Restorer, TargetConnectionDelegate> {
    S3RestorerParamSet *paramSet;
    id <S3RestorerDelegate> delegate;
    
    NSString *skipFilesRoot;

    NSMutableArray *calculateItems;
    NSMutableArray *restoreItems;
    NSMutableDictionary *hardlinks;

    Repo *repo;
    Commit *commit;
    NSString *commitDescription;
    Tree *rootTree;
    
    unsigned long long bytesTransferred;
    unsigned long long totalBytesToTransfer;
    
    unsigned long long writtenToCurrentFile;
}
- (id)initWithParamSet:(S3RestorerParamSet *)theParamSet
              delegate:(id <S3RestorerDelegate>)theDelegate;

@end
