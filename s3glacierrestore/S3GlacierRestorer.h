//
//  S3GlacierRestorer.h
//  Arq
//
//  Created by Stefan Reitshamer on 1/9/14.
//  Copyright (c) 2014 Stefan Reitshamer. All rights reserved.
//

#import "TargetConnection.h"
#import "Restorer.h"
@class S3GlacierRestorerParamSet;
@protocol S3GlacierRestorerDelegate;
@class Repo;
@class Commit;
@class Tree;



@interface S3GlacierRestorer : NSObject <Restorer, TargetConnectionDelegate> {
    S3GlacierRestorerParamSet *paramSet;
    id <S3GlacierRestorerDelegate> delegate;

    Repo *repo;
    Commit *commit;
    Tree *rootTree;
    
    NSMutableArray *calculateItems;
    NSMutableArray *glacierRequestItems;
    NSMutableArray *restoreItems;
    
    NSString *skipFilesRoot;
    
    unsigned long long bytesActuallyRequestedThisRound;
    unsigned long long bytesRequested;
    unsigned long long totalBytesToRequest;
    
    unsigned long long bytesTransferred;
    unsigned long long totalBytesToTransfer;
    
    unsigned long long bytesToRequestPerRound;
    NSDate *dateToResumeRequesting;
    NSUInteger roundsCompleted;
    NSMutableDictionary *hardlinks;
    
    NSUInteger sleepCycles;
}
- (id)initWithS3GlacierRestorerParamSet:(S3GlacierRestorerParamSet *)theParamSet delegate:(id <S3GlacierRestorerDelegate>)theDelegate;

- (void)run;
@end
