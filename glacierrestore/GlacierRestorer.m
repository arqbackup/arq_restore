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

#import "GlacierRestorer.h"
#import "GlacierRestorerParamSet.h"
#import "GlacierRestorerDelegate.h"
#import "S3AuthorizationProvider.h"
#import "S3Service.h"
#import "ArqSalt.h"
#import "Repo.h"
#import "Commit.h"
#import "Tree.h"
#import "Node.h"
#import "GlacierAuthorizationProvider.h"
#import "GlacierService.h"
#import "FileOutputStream.h"
#import "NSFileManager_extra.h"
#import "BlobKey.h"
#import "NSData-GZip.h"
#import "FileAttributes.h"
#import "BufferedOutputStream.h"
#import "OSStatusDescription.h"
#import "FileACL.h"
#import "BufferedInputStream.h"
#import "DataInputStream.h"
#import "XAttrSet.h"
#import "FileInputStream.h"
#import "SHA1Hash.h"
#import "PackIndexEntry.h"
#import "UserLibrary_Arq.h"
#import "SNS.h"
#import "SQS.h"
#import "NSString_extra.h"
#import "ReceiveMessageResponse.h"
#import "SQSMessage.h"
#import "NSObject+SBJSON.h"
#import "NSString+SBJSON.h"
#import "RestoreItem.h"
#import "GlacierRequestItem.h"
#import "CalculateItem.h"
#import "Bucket.h"
#import "Target.h"
#import "GlacierPackSet.h"
#import "GlacierPack.h"
#import "GlacierPackIndex.h"
#import "AWSRegion.h"
#import "Streams.h"


#define WAIT_TIME (3.0)
#define SLEEP_CYCLES (2)
#define MAX_QUEUE_MESSAGES_TO_READ (10)
#define MAX_GLACIER_RETRIES (10)

#define RESTORE_DAYS (10)


@implementation GlacierRestorer
- (id)initWithGlacierRestorerParamSet:(GlacierRestorerParamSet *)theParamSet
                             delegate:(id <GlacierRestorerDelegate>)theDelegate {
    if (self = [super init]) {
        paramSet = [theParamSet retain];
        delegate = theDelegate; // Don't retain it.

        bytesToRequestPerRound = paramSet.downloadBytesPerSecond * 60 * 60 * 4; // 4 hours at preferred download rate
        dateToResumeRequesting = [[NSDate date] retain];
        skipFilesRoot = [[[UserLibrary arqUserLibraryPath] stringByAppendingFormat:@"/RestoreJobSkipFiles/%f", [NSDate timeIntervalSinceReferenceDate]] retain];
        hardlinks = [[NSMutableDictionary alloc] init];        
        jobUUID = [[NSString stringWithRandomUUID] retain];
        requestedGlacierPacksByPackSHA1 = [[NSMutableDictionary alloc] init];
        glacierPacksToDownload = [[NSMutableArray alloc] init];

        calculateItems = [[NSMutableArray alloc] init];
        glacierRequestItems = [[NSMutableArray alloc] init];
        restoreItems = [[NSMutableArray alloc] init];
        requestedArchiveIds = [[NSMutableSet alloc] init];
    }
    return self;
}
- (void)dealloc {
    [paramSet release];
    
    [dateToResumeRequesting release];
    [skipFilesRoot release];
    [hardlinks release];
    [jobUUID release];
    [sns release];
    [sqs release];
    [s3 release];
    [glacier release];
    [glacierPackSet release];
    [requestedGlacierPacksByPackSHA1 release];
    [glacierPacksToDownload release];
    [calculateItems release];
    [glacierRequestItems release];
    [restoreItems release];
    [requestedArchiveIds release];

    [topicArn release];
    [queueURL release];
    [queueArn release];
    [subscriptionArn release];

    [repo release];
    [commit release];
    [commitDescription release];
    [rootTree release];

    [super dealloc];
}


- (void)run {
    HSLogDebug(@"GlacierRestorer starting");
    NSError *myError = nil;
    if (![self run:&myError]) {
        HSLogDebug(@"[GlacierRestorer run:] failed; %@", myError);
        [delegate glacierRestorerDidFail:myError];
    } else {
        HSLogDebug(@"[GlacierRestorer run:] succeeded");
        [delegate glacierRestorerDidSucceed];
    }
    
    [self deleteTopic];
    [self deleteQueue];

    NSError *removeError = nil;
    if ([[NSFileManager defaultManager] fileExistsAtPath:skipFilesRoot] && ![[NSFileManager defaultManager] removeItemAtPath:skipFilesRoot error:&removeError]) {
        HSLogError(@"failed to remove %@: %@", skipFilesRoot, removeError);
    }
    
    HSLogDebug(@"GlacierRestorer finished");
}
- (NSNumber *)isObjectAvailableForBlobKey:(BlobKey *)theBlobKey error:(NSError **)error {
    if ([theBlobKey storageType] == StorageTypeS3) {
        // In Repo.m doPutData (line 503) we were incorrectly creating a BlobKey with storageType hard-coded to StorageTypeS3 when it should have been StorageTypeS3Glacier.
        // Since we're here because we're restoring from a StorageTypeGlacier folder, we'll assume the storageType should be StorageTypeS3Glacier instead of StorageTypeS3.
        theBlobKey = [[[BlobKey alloc] initCopyOfBlobKey:theBlobKey withStorageType:StorageTypeS3Glacier] autorelease];
    }
    
    if ([theBlobKey storageType] == StorageTypeS3Glacier) {
        return [repo isObjectDownloadableForBlobKey:theBlobKey error:error];
    }
    
    // Packed blobs have sha1, but not archiveId.
    if ([theBlobKey archiveId] == nil) {
        return [NSNumber numberWithBool:YES];
    }
    NSError *myError = nil;
    NSString *jobId = [self completedJobIdForArchiveId:[theBlobKey archiveId] error:&myError];
    if (jobId == nil) {
        if ([myError code] == ERROR_GLACIER_OBJECT_NOT_AVAILABLE) {
            return [NSNumber numberWithBool:NO];
        }
        SETERRORFROMMYERROR;
        return nil;
    }
    return [NSNumber numberWithBool:YES];
}
- (NSNumber *)sizeOfBlob:(BlobKey *)theBlobKey error:(NSError **)error {
    if ([theBlobKey storageType] == StorageTypeGlacier) {
        return [NSNumber numberWithUnsignedLongLong:[theBlobKey archiveSize]];
    }
    
    unsigned long long dataSize = 0;
    NSNumber *contains = [repo containsBlobForBlobKey:theBlobKey dataSize:&dataSize error:error];
    if (contains == nil) {
        return NO;
    }
    if (![contains boolValue]) {
        // We'll report this to the user as an error during the download phase.
        HSLogError(@"repo does not contain %@!", theBlobKey);
    }
    return [NSNumber numberWithUnsignedLongLong:dataSize];
}
- (BOOL)requestBlobKey:(BlobKey *)theBlobKey error:(NSError **)error {
    if (theBlobKey == nil) {
        return YES;
    }
    
    if ([theBlobKey storageType] == StorageTypeS3) {
        // In Repo.m doPutData (line 503) we were incorrectly creating a BlobKey with storageType hard-coded to StorageTypeS3 when it should have been StorageTypeS3Glacier.
        // Since we're here because we're restoring from a StorageTypeGlacier folder, we'll assume the storageType should be StorageTypeS3Glacier instead of StorageTypeS3.
        theBlobKey = [[[BlobKey alloc] initCopyOfBlobKey:theBlobKey withStorageType:StorageTypeS3Glacier] autorelease];
    }
    
    if ([theBlobKey storageType] == StorageTypeS3Glacier) {
        unsigned long long dataSize = 0;
        NSNumber *contains = [repo containsBlobForBlobKey:theBlobKey dataSize:&dataSize error:error];
        if (contains == nil) {
            return NO;
        }
        
        if (![contains boolValue]) {
            // We'll report this to the user as an error during the download phase.
            HSLogError(@"repo does not contain %@!", theBlobKey);
        } else {
            BOOL alreadyRestoredOrRestoring = NO;
            if (![repo restoreObjectForBlobKey:theBlobKey forDays:RESTORE_DAYS alreadyRestoredOrRestoring:&alreadyRestoredOrRestoring error:error]) {
                return NO;
            }
            if (![self addToBytesRequested:dataSize error:error]) {
                return NO;
            }
        }
        return YES;
    }
    
    
    if ([theBlobKey archiveId] != nil) {
        if (![requestedArchiveIds containsObject:[theBlobKey archiveId]]) {
            if (![glacier initiateRetrievalJobForVaultName:[[paramSet bucket] vaultName]
                                                 archiveId:[theBlobKey archiveId]
                                               snsTopicArn:topicArn
                                                     error:error]) {
                return NO;
            }
            [requestedArchiveIds addObject:[theBlobKey archiveId]];
            HSLogDebug(@"requested %@", theBlobKey);
        }
        if (![self addToBytesRequested:[theBlobKey archiveSize] error:error]) {
            return NO;
        }
    }
    return YES;
}


#pragma mark Restorer
- (NSString *)errorDomain {
    return @"GlacierRestorerErrorDomain";
}
- (NSData *)dataForBlobKey:(BlobKey *)theBlobKey error:(NSError **)error {
    if ([theBlobKey storageType] == StorageTypeS3) {
        // In Repo.m doPutData (line 503) we were incorrectly creating a BlobKey with storageType hard-coded to StorageTypeS3 when it should have been StorageTypeS3Glacier.
        // Since we're here because we're restoring from a StorageTypeGlacier folder, we'll assume the storageType should be StorageTypeS3Glacier instead of StorageTypeS3.
        theBlobKey = [[[BlobKey alloc] initCopyOfBlobKey:theBlobKey withStorageType:StorageTypeS3Glacier] autorelease];
    }
    
    if ([theBlobKey storageType] == StorageTypeS3Glacier) {
        NSData *data = [repo dataForBlobKey:theBlobKey error:error];
        if (data == nil) {
            return nil;
        }
        if (![self addToBytesTransferred:(unsigned long long)[data length] error:error]) {
            return nil;
        }
        return data;
    }

    NSData *ret = nil;
    if ([theBlobKey archiveId] == nil) {
        // Packed blob.
        PackIndexEntry *pie = [glacierPackSet packIndexEntryForObjectSHA1:[theBlobKey sha1] targetConnectionDelegate:self error:error];
        if (pie == nil) {
            return nil;
        }
        GlacierPack *glacierPack = [requestedGlacierPacksByPackSHA1 objectForKey:[[pie packId] packSHA1]];
        if (glacierPack == nil) {
            SETNSERROR([self errorDomain], -1, @"no GlacierPack for packSHA1 %@", [[pie packId] packSHA1]);
            return nil;
        }
        ret = [glacierPack cachedDataForObjectAtOffset:[pie offset] error:error];
    } else {
        NSString *completedJobId = [self completedJobIdForArchiveId:[theBlobKey archiveId] error:error];
        if (completedJobId == nil) {
            return nil;
        }
        ret = [glacier dataForVaultName:[[paramSet bucket] vaultName] jobId:completedJobId retries:MAX_GLACIER_RETRIES error:error];
        if (ret != nil) {
            if (![self addToBytesTransferred:[ret length] error:error]) {
                return nil;
            }
        }
    }
    if (ret != nil) {
        ret = [repo decryptData:ret error:error];
    }
    return ret;
}
- (BOOL)shouldSkipFile:(NSString *)thePath {
    NSString *skipFilePath = [skipFilesRoot stringByAppendingString:thePath];
    return [[NSFileManager defaultManager] fileExistsAtPath:skipFilePath];
}
- (BOOL)useTargetUIDAndGID {
    return paramSet.useTargetUIDAndGID;
}
- (uid_t)targetUID {
    return paramSet.targetUID;
}
- (gid_t)targetGID {
    return paramSet.targetGID;
}


#pragma mark TargetConnectionDelegate
- (BOOL)targetConnectionShouldRetryOnTransientError:(NSError **)error {
    return YES;
}


#pragma mark internal
- (BOOL)run:(NSError **)error {
    if (![self setUp:error]) {
        return NO;
    }
    
    NSString *calculatingMessage = @"Calculating sizes";
    if ([[NSFileManager defaultManager] fileExistsAtPath:paramSet.destinationPath]) {
        calculatingMessage = @"Comparing existing files to backup data";
    }
    if ([delegate glacierRestorerMessageDidChange:calculatingMessage]) {
        SETNSERROR([self errorDomain], ERROR_ABORT_REQUESTED, @"cancel requested");
        return NO;
    }
    if (![self calculateSizes:error]) {
        return NO;
    }

    
    if ([delegate glacierRestorerMessageDidChange:[NSString stringWithFormat:@"Restoring %@ from %@ to %@", paramSet.rootItemName, commitDescription, paramSet.destinationPath]]) {
        SETNSERROR([self errorDomain], ERROR_ABORT_REQUESTED, @"cancel requested");
        return NO;
    }
    if (![self findNeededGlacierPacks:error]) {
        return NO;
    }
    
    // Just request all the Glacier packs right away. It probably won't amount to more than 4 hours' worth of downloads.
    for (GlacierPack *glacierPack in [requestedGlacierPacksByPackSHA1 allValues]) {
        if (![glacier initiateRetrievalJobForVaultName:[[paramSet bucket] vaultName]
                                             archiveId:[glacierPack archiveId]
                                           snsTopicArn:topicArn
                                                 error:error]) {
            return NO;
        }
        if (![self addToBytesRequested:[glacierPack packSize] error:error]) {
            return NO;
        }
    }
    
    
    BOOL restoredAnItem = NO;
    BOOL ret = YES;
    NSAutoreleasePool *pool = nil;
    for (;;) {
        [pool drain];
        pool = [[NSAutoreleasePool alloc] init];
        
        // Reset counters if necessary.
        if (bytesRequestedThisRound >= bytesToRequestPerRound) {
            roundsCompleted++;
            bytesRequestedThisRound = 0;
            NSDate *nextResumeDate = [[dateToResumeRequesting dateByAddingTimeInterval:(60 * 60 * 4)] retain];
            [dateToResumeRequesting release];
            dateToResumeRequesting = nextResumeDate;
            HSLogDebug(@"reset next request resume date to %@", nextResumeDate);
        }
        
        // Make sure we've transferred all the bytes from all but the most recent round of requests.
        double theMinimum = (roundsCompleted = 0) ? 0 : ((double)bytesToRequestPerRound * (double)(roundsCompleted - 1)) * .9;
        unsigned long long minimumBytesToHaveTransferred = (unsigned long long)theMinimum;
        if ((bytesRequestedThisRound < bytesToRequestPerRound)
            && (bytesTransferred >= minimumBytesToHaveTransferred)
            && ([[NSDate date] earlierDate:dateToResumeRequesting] == dateToResumeRequesting)) {
            
            // Request more Glacier items.
            if (![self requestMoreGlacierItems:error]) {
                ret = NO;
                break;
            }
        }
        
        if (!restoredAnItem) {
            // Read any available items from the queue.
            HSLogDebug(@"reading queue");
            if (![self readQueue:error]) {
                ret = NO;
                break;
            }
        }
        
        if ([glacierPacksToDownload count] == 0 && [restoreItems count] == 0) {
            HSLogDebug(@"finished requesting");
            if ([delegate glacierRestorerDidFinishRequesting]) {
                SETNSERROR([self errorDomain], ERROR_ABORT_REQUESTED, @"cancel requested");
                ret = NO;
                break;
            }
            break;
        }
        
        
        // Restore an item if possible.
        
        if ([glacierPacksToDownload count] > 0) {
            GlacierPack *glacierPack = [glacierPacksToDownload objectAtIndex:0];
            NSError *myError = nil;
            NSString *completedJobId = [self completedJobIdForArchiveId:[glacierPack archiveId] error:&myError];
            if (completedJobId == nil) {
                if ([myError code] != ERROR_GLACIER_OBJECT_NOT_AVAILABLE) {
                    SETERRORFROMMYERROR;
                    ret = NO;
                    break;
                }
                HSLogDebug(@"%@ not available yet", glacierPack);
                restoredAnItem = NO;
            } else {
                HSLogDebug(@"downloading %@", glacierPack);
                NSData *packData = [glacier dataForVaultName:[[paramSet bucket] vaultName] jobId:completedJobId retries:MAX_GLACIER_RETRIES error:error];
                if (packData == nil) {
                    ret = NO;
                    break;
                }
                restoredAnItem = YES;
                if (![self addToBytesTransferred:[packData length] error:error]) {
                    ret = NO;
                    break;
                }
                if (![glacierPack cachePackDataToDisk:packData error:error]) {
                    ret = NO;
                    break;
                }
                HSLogDebug(@"downloaded %@", glacierPack);
                [glacierPacksToDownload removeObject:glacierPack];
                restoredAnItem = YES;
            }

        } else {
            NSError *restoreError = nil;
            RestoreItem *restoreItem = [restoreItems objectAtIndex:0];
            restoredAnItem = YES;
            HSLogDebug(@"attempting to restore %@", restoreItem);
            if (![restoreItem restoreWithHardlinks:hardlinks restorer:self error:&restoreError]) {
                if ([restoreError code] == ERROR_GLACIER_OBJECT_NOT_AVAILABLE) {
                    HSLogDebug(@"glacier object not available yet");
                    restoredAnItem = NO;
                } else if ([restoreError isErrorWithDomain:[self errorDomain] code:ERROR_ABORT_REQUESTED]) {
                    if (error != NULL) {
                        *error = restoreError;
                    }
                    ret = NO;
                    break;
                } else {
                    [delegate glacierRestorerErrorMessage:[restoreError localizedDescription] didOccurForPath:[restoreItem path]];
                }
            }
            if (restoredAnItem) {
                NSArray *nextItems = [restoreItem nextItemsWithRepo:repo error:error];
                if (nextItems == nil) {
                    ret = NO;
                    break;
                }
                [restoreItems removeObjectAtIndex:0];
                if ([nextItems count] > 0) {
                    [restoreItems insertObjects:nextItems atIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [nextItems count])]];
                }
            }
        }
        
        if (!restoredAnItem) {
            HSLogDebug(@"sleeping");
            for (NSUInteger i = 0; i < SLEEP_CYCLES; i++) {
                if (![self addToBytesTransferred:0 error:error]) {
                    ret = NO;
                    break;
                }
                [NSThread sleepForTimeInterval:3.0];
            }
        }
        if (!ret) {
            break;
        }
    }
    if (!ret && error != NULL) {
        [*error retain];
    }
    [pool drain];
    if (!ret && error != NULL) {
        [*error autorelease];
    }
    return ret;
}
- (BOOL)setUp:(NSError **)error {
    NSString *secretAccessKey = [[[paramSet bucket] target] secret:error];
    if (secretAccessKey == nil) {
        return NO;
    }
    
    AWSRegion *awsRegion = [AWSRegion regionWithS3Endpoint:[[[paramSet bucket] target] endpoint]];
    if (awsRegion == nil) {
        SETNSERROR([self errorDomain], -1, @"unknown AWS region %@", [[[paramSet bucket] target] endpoint]);
        return NO;
    }
    sns = [[SNS alloc] initWithAccessKey:[[[[paramSet bucket] target] endpoint] user] secretKey:secretAccessKey awsRegion:awsRegion retryOnTransientError:YES];
    sqs = [[SQS alloc] initWithAccessKey:[[[[paramSet bucket] target] endpoint] user] secretKey:secretAccessKey awsRegion:awsRegion retryOnTransientError:YES];
    s3 = [[[[paramSet bucket] target] s3:error] retain];
    if (s3 == nil) {
        return NO;
    }
    GlacierAuthorizationProvider *gap = [[[GlacierAuthorizationProvider alloc] initWithAccessKey:[[[[paramSet bucket] target] endpoint] user] secretKey:secretAccessKey] autorelease];
    glacier = [[GlacierService alloc] initWithGlacierAuthorizationProvider:gap awsRegion:awsRegion useSSL:YES retryOnTransientError:YES];
    glacierPackSet = [[GlacierPackSet alloc] initWithTarget:[[paramSet bucket] target]
                                                         s3:s3
                                                    glacier:glacier
                                                  vaultName:[[paramSet bucket] vaultName]
                                               s3BucketName:[[[[[paramSet bucket] target] endpoint] path] lastPathComponent]
                                               computerUUID:[[paramSet bucket] computerUUID]
                                                packSetName:[[[paramSet bucket] bucketUUID] stringByAppendingString:@"-glacierblobs"]
                                                  targetUID:paramSet.targetUID
                                                  targetGID:paramSet.targetGID];
    ArqSalt *arqSalt = [[[ArqSalt alloc] initWithTarget:[[paramSet bucket] target] targetUID:[paramSet targetUID] targetGID:[paramSet targetGID] computerUUID:[[paramSet bucket] computerUUID]] autorelease];
    NSData *salt = [arqSalt saltWithTargetConnectionDelegate:self error:error];
    if (salt == nil) {
        return NO;
    }
    repo = [[Repo alloc] initWithBucket:[paramSet bucket]
                     encryptionPassword:[paramSet encryptionPassword]
                              targetUID:[paramSet targetUID]
                              targetGID:[paramSet targetGID]
           loadExistingMutablePackFiles:NO
               targetConnectionDelegate:self
                           repoDelegate:nil
                                  error:error];
    if (repo == nil) {
        return NO;
    }
    commit = [[repo commitForBlobKey:paramSet.commitBlobKey error:error] retain];
    if (commit == nil) {
        return NO;
    }
    NSDateFormatter *dateFormatter = [[[NSDateFormatter alloc] init] autorelease];
    [dateFormatter setDateStyle:NSDateFormatterMediumStyle];
    [dateFormatter setTimeStyle:NSDateFormatterShortStyle];
    commitDescription = [[dateFormatter stringFromDate:[commit creationDate]] retain];
    
    rootTree = [[repo treeForBlobKey:paramSet.treeBlobKey error:error] retain];
    if (rootTree == nil) {
        return NO;
    }

    if ([delegate glacierRestorerMessageDidChange:[NSString stringWithFormat:@"Creating SNS topic and SQS queue"]]) {
        SETNSERROR([self errorDomain], ERROR_ABORT_REQUESTED, @"cancel requested");
        return NO;
    }
    
    topicArn = [[sns createTopic:[NSString stringWithFormat:@"%@_topic", jobUUID] error:error] retain];
    if (topicArn == nil) {
        return NO;
    }
    queueURL = [[sqs createQueueWithName:[NSString stringWithFormat:@"%@_queue", jobUUID] error:error] retain];
    if (queueURL == nil) {
        return NO;
    }
    queueArn = [[sqs queueArnForQueueURL:queueURL error:error] retain];
    if (queueArn == nil) {
        return NO;
    }
    if (![sqs setSendMessagePermissionToQueueURL:queueURL queueArn:queueArn forSourceArn:topicArn error:error]) {
        return NO;
    }
    subscriptionArn = [[sns subscribeQueueArn:queueArn toTopicArn:topicArn error:error] retain];
    if (subscriptionArn == nil) {
        return NO;
    }

    if (paramSet.nodeName != nil) {
        Node *node = [rootTree childNodeWithName:paramSet.nodeName];
        if ([[rootTree childNodeNames] isEqualToArray:[NSArray arrayWithObject:@"."]]) {
            // The single-file case.
            node = [rootTree childNodeWithName:@"."];
        }
        NSAssert(node != nil, @"node can't be nil");
        
        [calculateItems addObject:[[[CalculateItem alloc] initWithPath:paramSet.destinationPath node:node] autorelease]];
        [glacierRequestItems addObject:[[[GlacierRequestItem alloc] initWithPath:paramSet.destinationPath node:node] autorelease]];
        [restoreItems addObject:[[[RestoreItem alloc] initWithPath:paramSet.destinationPath tree:rootTree node:node] autorelease]];
    } else {
        [calculateItems addObject:[[[CalculateItem alloc] initWithPath:paramSet.destinationPath tree:rootTree] autorelease]];
        [glacierRequestItems addObject:[[[GlacierRequestItem alloc] initWithPath:paramSet.destinationPath tree:rootTree] autorelease]];
        [restoreItems addObject:[[[RestoreItem alloc] initWithPath:paramSet.destinationPath tree:rootTree] autorelease]];
    }

    return YES;
}
- (BOOL)calculateSizes:(NSError **)error {
    BOOL ret = YES;
    NSAutoreleasePool *pool = nil;
    while ([calculateItems count] > 0) {
        [pool drain];
        pool = [[NSAutoreleasePool alloc] init];
        
        CalculateItem *item = [calculateItems objectAtIndex:0];
        if (![item calculateWithRepo:repo restorer:self error:error]) {
            ret = NO;
            break;
        }
        for (NSString *path in [item filesToSkip]) {
            [self skipFile:path];
        }
        unsigned long long bytesToTransfer = [item bytesToTransfer];
        if (![self addToTotalBytesToRequest:bytesToTransfer error:error]) {
            ret = NO;
            break;
        }
        if (![self addToTotalBytesToTransfer:bytesToTransfer error:error]) {
            ret = NO;
            break;
        }
        [calculateItems removeObjectAtIndex:0];
        NSArray *nextItems = [item nextItems];
        if ([nextItems count] > 0) {
            [calculateItems insertObjects:nextItems atIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [nextItems count])]];
        }
    }
    if (!ret && error != NULL) {
        [*error retain];
    }
    [pool drain];
    if (!ret && error != NULL) {
        [*error autorelease];
    }
    
    return ret;
}
- (void)skipFile:(NSString *)thePath {
    NSString *skipFilePath = [skipFilesRoot stringByAppendingString:thePath];
    NSError *myError = nil;
    if (![[NSFileManager defaultManager] ensureParentPathExistsForPath:skipFilePath targetUID:paramSet.targetUID targetGID:paramSet.targetGID error:&myError]) {
        HSLogError(@"error creating parent dir for %@: %@", skipFilePath, myError);
        return;
    }
    if (![[NSFileManager defaultManager] touchFileAtPath:skipFilePath targetUID:paramSet.targetUID targetGID:paramSet.targetGID error:&myError]) {
        HSLogError(@"error touching %@: %@", skipFilePath, myError);
    }
    HSLogDebug(@"skip file %@", thePath);
}

- (BOOL)findNeededGlacierPacks:(NSError **)error {
    HSLogDebug(@"finding needed glacier packs");
    if (paramSet.nodeName != nil) {
        Node *node = [rootTree childNodeWithName:paramSet.nodeName];
        if ([[rootTree childNodeNames] isEqualToArray:[NSArray arrayWithObject:@"."]]) {
            // The single-file case.
            node = [rootTree childNodeWithName:@"."];
        }
        NSAssert(node != nil, @"node can't be nil");
        if (![self findNeededGlacierPacksForNode:node path:paramSet.destinationPath error:error]) {
            return NO;
        }
    } else {
        if (![self findNeededGlacierPacksForTree:rootTree path:paramSet.destinationPath error:error]) {
            return NO;
        }
    }

    [glacierPacksToDownload setArray:[requestedGlacierPacksByPackSHA1 allValues]];
    
    HSLogDebug(@"found %ld needed glacier packs", (unsigned long)[requestedGlacierPacksByPackSHA1 count]);
    return YES;
}
- (BOOL)findNeededGlacierPacksForTree:(Tree *)theTree path:(NSString *)thePath error:(NSError **)error {
    HSLogDebug(@"requesting glacier packs for tree xattrs %@", [theTree xattrsBlobKey]);
    if (![self findNeededGlacierPackForBlobKey:[theTree xattrsBlobKey] error:error]) {
        return NO;
    }
    HSLogDebug(@"requesting glacier packs for tree acl %@", [theTree aclBlobKey]);
    if (![self findNeededGlacierPackForBlobKey:[theTree aclBlobKey] error:error]) {
        return NO;
    }
    
    BOOL ret = YES;
    NSAutoreleasePool *pool = nil;
    for (NSString *nodeName in [theTree childNodeNames]) {
        [pool drain];
        pool = [[NSAutoreleasePool alloc] init];
        Node *node = [theTree childNodeWithName:nodeName];
        NSString *childPath = [thePath stringByAppendingPathComponent:nodeName];
        if ([node isTree]) {
            Tree *childTree = [repo treeForBlobKey:[node treeBlobKey] error:error];
            if (childTree == nil) {
                ret = NO;
                break;
            }
            if (![self findNeededGlacierPacksForTree:childTree path:childPath error:error]) {
                ret = NO;
                break;
            }
        } else {
            if (![self findNeededGlacierPacksForNode:node path:childPath error:error]) {
                ret = NO;
                break;
            }
        }
    }
    if (!ret && error != NULL) {
        [*error retain];
    }
    [pool drain];
    if (!ret && error != NULL) {
        [*error autorelease];
    }
    return ret;
}
- (BOOL)findNeededGlacierPacksForNode:(Node *)theNode path:(NSString *)thePath error:(NSError **)error {
    if (![self findNeededGlacierPackForBlobKey:[theNode xattrsBlobKey] error:error]) {
        return NO;
    }
    if (![self findNeededGlacierPackForBlobKey:[theNode aclBlobKey] error:error]) {
        return NO;
    }
    
    BOOL ret = YES;
    if (![self shouldSkipFile:thePath]) {
        for (BlobKey *dataBlobKey in [theNode dataBlobKeys]) {
            if (![self findNeededGlacierPackForBlobKey:dataBlobKey error:error]) {
                ret = NO;
                break;
            }
        }
    }
    return ret;
}
- (BOOL)findNeededGlacierPackForBlobKey:(BlobKey *)theBlobKey error:(NSError **)error {
    // Packed blobs have sha1, but not archiveId.
    if (theBlobKey != nil && [theBlobKey storageType] == StorageTypeGlacier && [theBlobKey archiveId] == nil) {
        NSString *theSHA1 = [theBlobKey sha1];
        NSError *myError = nil;
        GlacierPackIndex *glacierPackIndex = [glacierPackSet glacierPackIndexForObjectSHA1:theSHA1 targetConnectionDelegate:self error:&myError];
        if (glacierPackIndex == nil) {
            if ([myError code] == ERROR_NOT_FOUND) {
                HSLogError(@"object SHA1 %@ not found in any glacier pack index", theSHA1);
            } else {
                SETERRORFROMMYERROR;
                return NO;
            }
        } else if (![[requestedGlacierPacksByPackSHA1 allKeys] containsObject:[[glacierPackIndex packId] packSHA1]]) {
            NSString *archiveId = [glacierPackIndex archiveId:error];
            if (archiveId == nil) {
                return NO;
            }
            unsigned long long packSize = [glacierPackIndex packSize:error];
            if (packSize == 0) {
                return NO;
            }
            
            HSLogDebug(@"need glacier pack SHA1 %@ archiveId %@", [[glacierPackIndex packId] packSHA1], archiveId);
            
            if (![self addToTotalBytesToRequest:packSize error:error]) {
                return NO;
            }
            if (![self addToTotalBytesToTransfer:packSize error:error]) {
                return NO;
            }
            
            GlacierPack *glacierPack = [[[GlacierPack alloc] initWithTarget:[[paramSet bucket] target]
                                                               s3BucketName:[[[[[paramSet bucket] target] endpoint] path] lastPathComponent]
                                                               computerUUID:[[paramSet bucket] computerUUID]
                                                                 bucketUUID:[[paramSet bucket] bucketUUID]
                                                                   packSHA1:[[glacierPackIndex packId] packSHA1]
                                                                  archiveId:archiveId
                                                                   packSize:packSize
                                                                  targetUID:[paramSet targetUID]
                                                                  targetGID:[paramSet targetGID]] autorelease];
            [requestedGlacierPacksByPackSHA1 setObject:glacierPack forKey:[[glacierPackIndex packId] packSHA1]];
        }
    }
    return YES;
}

- (BOOL)readQueue:(NSError **)error {
    BOOL ret = YES;
    NSAutoreleasePool *pool = nil;
    for (;;) {
        [pool drain];
        pool = [[NSAutoreleasePool alloc] init];
        ReceiveMessageResponse *response = [sqs receiveMessagesForQueueURL:queueURL maxMessages:MAX_QUEUE_MESSAGES_TO_READ error:error];
        if (response == nil) {
            ret = NO;
            break;
        }
        HSLogDebug(@"got %lu messages from queue", (unsigned long)[[response messages] count]);
        if ([[response messages] count] == 0) {
            break;
        }
        for (SQSMessage *msg in [response messages]) {
            if (![self processMessage:msg error:error]) {
                ret = NO;
                break;
            }
        }
    }
    if (!ret && error != NULL) {
        [*error retain];
    }
    [pool drain];
    if (!ret && error != NULL) {
        [*error autorelease];
    }
    return ret;
}
- (BOOL)processMessage:(SQSMessage *)theMessage error:(NSError **)error {
    NSDictionary *json = [[theMessage body] JSONValue:error];
    if (json == nil) {
        return NO;
    }
    id msgJson = [json objectForKey:@"Message"];
    
    // Sometimes it comes back as an NSString, sometimes already as an NSDictionary?!
    if ([msgJson isKindOfClass:[NSString class]]) {
        msgJson = [(NSString *)msgJson JSONValue:error];
        if (msgJson == nil) {
            return NO;
        }
    }
    NSDictionary *msgDict = (NSDictionary *)msgJson;
    
    NSString *archiveId = [msgDict objectForKey:@"ArchiveId"];
    NSString *jobId = [msgDict objectForKey:@"JobId"];
    NSNumber *completed = [msgDict objectForKey:@"Completed"];
    NSAssert([completed boolValue], @"Completed must be YES");
    
    HSLogDetail(@"archiveId %@ is now available", archiveId);
    
    if (![self saveCompletedJobWithJobId:jobId archiveId:archiveId error:error]) {
        return NO;
    }
    
    NSError *myError = nil;
    if (![sqs deleteMessageWithQueueURL:queueURL receiptHandle:[theMessage receiptHandle] error:&myError]) {
        HSLogError(@"error deleting message %@ from queue %@: %@", [theMessage receiptHandle], queueURL, myError);
    }
    return YES;
}
- (BOOL)requestMoreGlacierItems:(NSError **)error {
    BOOL ret = YES;
    NSAutoreleasePool *pool = nil;
    while (bytesRequestedThisRound < bytesToRequestPerRound && [glacierRequestItems count] > 0) {
        [pool drain];
        pool = [[NSAutoreleasePool alloc] init];
        GlacierRequestItem *item = [glacierRequestItems objectAtIndex:0];
        NSArray *nextItems = [item requestWithRestorer:self repo:repo error:error];
        if (nextItems == nil) {
            ret = NO;
            break;
        }
        [glacierRequestItems removeObjectAtIndex:0];
        if ([nextItems count] > 0) {
            [glacierRequestItems insertObjects:nextItems atIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [nextItems count])]];
        }
    }
    if (!ret && error != NULL) {
        [*error retain];
    }
    [pool drain];
    if (!ret && error != NULL) {
        [*error autorelease];
    }
    return ret;
}

- (NSString *)completedJobIdForArchiveId:(NSString *)theArchiveId error:(NSError **)error {
    NSString *ret = nil;
    NSString *statusPath = [self statusPathForArchiveId:theArchiveId];
    if ([[NSFileManager defaultManager] fileExistsAtPath:statusPath]) {
        NSDictionary *attribs = [[NSFileManager defaultManager] attributesOfItemAtPath:statusPath error:error];
        if (attribs == nil) {
            return NO;
        }
        if ([[attribs objectForKey:NSFileSize] unsignedLongLongValue] > 0) {
            NSData *jobIdData = [NSData dataWithContentsOfFile:statusPath options:NSUncachedRead error:error];
            if (jobIdData == nil) {
                return NO;
            }
            ret = [[[NSString alloc] initWithData:jobIdData encoding:NSUTF8StringEncoding] autorelease];
        }
    }
    if (!ret) {
        SETNSERROR([self errorDomain], ERROR_GLACIER_OBJECT_NOT_AVAILABLE, @"object not available for archive %@", theArchiveId);
    }
    return ret;
}
- (BOOL)didRequestArchiveId:(NSString *)theArchiveId error:(NSError **)error {
    NSString *path = [self statusPathForArchiveId:theArchiveId];
    NSData *emptyData = [NSData data];
    if (![[NSFileManager defaultManager] ensureParentPathExistsForPath:path targetUID:paramSet.targetUID targetGID:paramSet.targetGID error:error]
        || ![Streams writeData:emptyData atomicallyToFile:path targetUID:[paramSet targetUID] targetGID:[paramSet targetGID] bytesWritten:NULL error:error]) {
        return NO;
    }
    return YES;
}
- (BOOL)saveCompletedJobWithJobId:(NSString *)theJobId archiveId:(NSString *)theArchiveId error:(NSError **)error {
    NSString *path = [self statusPathForArchiveId:theArchiveId];
    NSData *jobIdData = [theJobId dataUsingEncoding:NSUTF8StringEncoding];
    if (![[NSFileManager defaultManager] ensureParentPathExistsForPath:path targetUID:paramSet.targetUID targetGID:paramSet.targetGID error:error]
        || ![Streams writeData:jobIdData atomicallyToFile:path targetUID:paramSet.targetUID targetGID:paramSet.targetGID bytesWritten:NULL error:error]) {
        return NO;
    }
    return YES;
}
- (NSString *)statusPathForArchiveId:(NSString *)theArchiveId {
    return [[UserLibrary arqUserLibraryPath] stringByAppendingFormat:@"/RestoreJobData/%@/%@/%@/%@",
            [[paramSet bucket] computerUUID],
            jobUUID,
            [theArchiveId substringToIndex:2],
            [theArchiveId substringFromIndex:2]];
}
- (BOOL)addToBytesRequested:(unsigned long long)length error:(NSError **)error {
    bytesRequested += length;
    bytesRequestedThisRound += length;
    if ([delegate glacierRestorerBytesRequestedDidChange:[NSNumber numberWithUnsignedLongLong:bytesRequested]]) {
        SETNSERROR([self errorDomain], ERROR_ABORT_REQUESTED, @"cancel requested");
        return NO;
    }
    return YES;
}
- (BOOL)addToTotalBytesToRequest:(unsigned long long)length error:(NSError **)error {
    totalBytesToRequest += length;
    if ([delegate glacierRestorerTotalBytesToRequestDidChange:[NSNumber numberWithUnsignedLongLong:totalBytesToRequest]]) {
        SETNSERROR([self errorDomain], ERROR_ABORT_REQUESTED, @"cancel requested");
        return NO;
    }
    return YES;
}
- (BOOL)addToBytesTransferred:(unsigned long long)length error:(NSError **)error {
    bytesTransferred += length;
    if ([delegate glacierRestorerBytesTransferredDidChange:[NSNumber numberWithUnsignedLongLong:bytesTransferred]]) {
        SETNSERROR([self errorDomain], ERROR_ABORT_REQUESTED, @"cancel requested");
        return NO;
    }
    return YES;
}
- (BOOL)addToTotalBytesToTransfer:(unsigned long long)length error:(NSError **)error {
    totalBytesToTransfer += length;
    if ([delegate glacierRestorerTotalBytesToTransferDidChange:[NSNumber numberWithUnsignedLongLong:totalBytesToTransfer]]) {
        SETNSERROR([self errorDomain], ERROR_ABORT_REQUESTED, @"cancel requested");
        return NO;
    }
    return YES;
}
- (void)deleteQueue {
    if (queueURL != nil) {
        NSError *myError = nil;
        HSLogDetail(@"delete SQS queue %@", queueURL);
        if (![sqs deleteQueue:queueURL error:&myError]) {
            HSLogError(@"error deleting queue %@: %@", queueURL, myError);
        }
    }
}
- (void)deleteTopic {
    if (topicArn != nil) {
        NSError *myError = nil;
        HSLogDetail(@"deleting SNS topic %@", topicArn);
        if (![sns deleteTopicWithArn:topicArn error:&myError]) {
            HSLogError(@"error deleting SNS topic %@: %@", topicArn, myError);
        }
    }
}
@end
