//
//  GlacierRestorer.h
//  Arq
//
//  Created by Stefan Reitshamer on 5/29/13.
//  Copyright (c) 2013 Stefan Reitshamer. All rights reserved.
//

#import "Restorer.h"
#import "TargetConnection.h"
@class GlacierRestorerParamSet;
@protocol GlacierRestorerDelegate;
@class SNS;
@class SQS;
@class S3Service;
@class GlacierService;
@class GlacierPackSet;
@class Repo;
@class Commit;
@class Tree;
@class BlobKey;


@interface GlacierRestorer : NSObject <Restorer, TargetConnectionDelegate> {
    GlacierRestorerParamSet *paramSet;
    id <GlacierRestorerDelegate> delegate;
    
    unsigned long long bytesToRequestPerRound;
    NSDate *dateToResumeRequesting;
    NSString *skipFilesRoot;
    NSMutableDictionary *hardlinks;
    NSString *jobUUID;
    SNS *sns;
    SQS *sqs;
    S3Service *s3;
    GlacierService *glacier;
    GlacierPackSet *glacierPackSet;
    NSMutableSet *requestedGlacierPackSHA1s;
    NSMutableDictionary *requestedGlacierPacksByPackSHA1;
    NSMutableArray *glacierPacksToDownload;
    NSMutableArray *calculateItems;
    NSMutableArray *glacierRequestItems;
    NSMutableArray *restoreItems;
    NSMutableSet *requestedArchiveIds;

    NSString *topicArn;
    NSURL *queueURL;
    NSString *queueArn;
    NSString *subscriptionArn;

    Repo *repo;
    Commit *commit;
    NSString *commitDescription;
    Tree *rootTree;
    NSUInteger roundsCompleted;
    unsigned long long bytesRequestedThisRound;
    unsigned long long bytesRequested;
    unsigned long long totalBytesToRequest;
    
    unsigned long long bytesTransferred;
    unsigned long long totalBytesToTransfer;
    
    unsigned long long writtenToCurrentFile;
}
- (id)initWithGlacierRestorerParamSet:(GlacierRestorerParamSet *)theParamSet
                             delegate:(id <GlacierRestorerDelegate>)theDelegate;

- (void)run;
@end
