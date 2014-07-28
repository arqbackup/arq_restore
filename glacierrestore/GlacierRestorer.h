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
