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


#import "S3GlacierRestorer.h"
#import "S3GlacierRestorerParamSet.h"
#import "S3GlacierRestorerDelegate.h"
#import "commit.h"
#import "Tree.h"
#import "Node.h"
#import "Repo.h"
#import "CalculateItem.h"
#import "GlacierRequestItem.h"
#import "RestoreItem.h"
#import "NSFileManager_extra.h"
#import "UserLibrary_Arq.h"
#import "BlobKey.h"
#import "Bucket.h"
#import "Target.h"
#import "S3Service.h"


#define RESTORE_DAYS (10)

#define SLEEP_CYCLES_START (1)
#define SLEEP_CYCLES_MAX (30)
#define SLEEP_CYCLE_DURATION (2.0)


@implementation S3GlacierRestorer
- (id)initWithS3GlacierRestorerParamSet:(S3GlacierRestorerParamSet *)theParamSet delegate:(id <S3GlacierRestorerDelegate>)theDelegate {
    if (self = [super init]) {
        paramSet = [theParamSet retain];
        delegate = theDelegate;
        
        calculateItems = [[NSMutableArray alloc] init];
        glacierRequestItems = [[NSMutableArray alloc] init];
        restoreItems = [[NSMutableArray alloc] init];
        
        skipFilesRoot = [[[UserLibrary arqUserLibraryPath] stringByAppendingFormat:@"/RestoreJobSkipFiles/%f", [NSDate timeIntervalSinceReferenceDate]] retain];
        
        bytesToRequestPerRound = paramSet.downloadBytesPerSecond * 60 * 60 * 4; // 4 hours at preferred download rate
        dateToResumeRequesting = [[NSDate date] retain];
        hardlinks = [[NSMutableDictionary alloc] init];

        sleepCycles = SLEEP_CYCLES_START;
    }
    return self;
}
- (void)dealloc {
    [paramSet release];
    [repo release];
    [commit release];
    [rootTree release];
    [calculateItems release];
    [glacierRequestItems release];
    [restoreItems release];
    [skipFilesRoot release];
    [dateToResumeRequesting release];
    [hardlinks release];
    [super dealloc];
}

- (NSString *)errorDomain {
    return @"S3GlacierRestorerErrorDomain";
}

- (void)run {
    NSError *myError = nil;
    if (![self run:&myError]) {
        [delegate s3GlacierRestorerDidFail:myError];
    } else {
        [delegate s3GlacierRestorerDidSucceed];
    }

    
    NSError *removeError = nil;
    if ([[NSFileManager defaultManager] fileExistsAtPath:skipFilesRoot] && ![[NSFileManager defaultManager] removeItemAtPath:skipFilesRoot error:&removeError]) {
        HSLogError(@"failed to remove %@: %@", skipFilesRoot, removeError);
    }
    
    HSLogDebug(@"S3GlacierRestorer finished");
}


#pragma mark Restorer
- (BOOL)requestBlobKey:(BlobKey *)theBlobKey error:(NSError **)error {
    if (theBlobKey == nil) {
        return YES;
    }
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
        unsigned long long actualBytesRequested = alreadyRestoredOrRestoring ? 0 : dataSize;
        if (![self addToBytesRequested:dataSize actualBytesRequested:actualBytesRequested error:error]) {
            return NO;
        }
        
    }
    return YES;
}
- (NSNumber *)isObjectAvailableForBlobKey:(BlobKey *)theBlobKey error:(NSError **)error {
    return [repo isObjectDownloadableForBlobKey:theBlobKey error:error];
}
- (NSNumber *)sizeOfBlob:(BlobKey *)theBlobKey error:(NSError **)error {
    unsigned long long size = 0;
    NSNumber *contains = [repo containsBlobForBlobKey:theBlobKey dataSize:&size error:error];
    if (contains == nil) {
        return nil;
    }
    if (![contains boolValue]) {
        SETNSERROR([self errorDomain], ERROR_NOT_FOUND, @"size of blob %@ not found because blob not found", theBlobKey);
        return NO;
    }
    return [NSNumber numberWithUnsignedLongLong:size];
}
- (NSData *)dataForBlobKey:(BlobKey *)theBlobKey error:(NSError **)error {
    NSData *data = [repo dataForBlobKey:theBlobKey error:error];
    if (data == nil) {
        return nil;
    }
    if (![self addToBytesTransferred:(unsigned long long)[data length] error:error]) {
        return nil;
    }
    return data;
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


#pragma mark internal
- (BOOL)run:(NSError **)error {
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
    
    commit = [[repo commitForBlobKey:[paramSet commitBlobKey] dataSize:NULL error:error] retain];
    if (commit == nil) {
        return NO;
    }
    
    rootTree = [[repo treeForBlobKey:[paramSet treeBlobKey] dataSize:NULL error:error] retain];
    if (rootTree == nil) {
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

    NSString *calculatingMessage = @"Calculating sizes";
    if ([[NSFileManager defaultManager] fileExistsAtPath:paramSet.destinationPath]) {
        calculatingMessage = @"Comparing existing files to backup data";
    }
    if ([delegate s3GlacierRestorerMessageDidChange:calculatingMessage]) {
        SETNSERROR([self errorDomain], ERROR_ABORT_REQUESTED, @"cancel requested");
        return NO;
    }
    if (![self calculateSizes:error]) {
        return NO;
    }
    
    
    NSDateFormatter *dateFormatter = [[[NSDateFormatter alloc] init] autorelease];
    [dateFormatter setDateStyle:NSDateFormatterMediumStyle];
    [dateFormatter setTimeStyle:NSDateFormatterShortStyle];
    NSString *commitDescription = [dateFormatter stringFromDate:[commit creationDate]];
    if ([delegate s3GlacierRestorerMessageDidChange:[NSString stringWithFormat:@"Restoring %@ from %@ to %@", paramSet.rootItemName, commitDescription, paramSet.destinationPath]]) {
        SETNSERROR([self errorDomain], ERROR_ABORT_REQUESTED, @"cancel requested");
        return NO;
    }
    
    
    BOOL restoredAnItem = NO;
    BOOL ret = YES;
    NSAutoreleasePool *pool = nil;
    while ([restoreItems count] > 0) {
        [pool drain];
        pool = [[NSAutoreleasePool alloc] init];
        
        if ([glacierRequestItems count] > 0) {
            // Reset counters if necessary.
            if (bytesActuallyRequestedThisRound >= bytesToRequestPerRound) {
                roundsCompleted++;
                bytesActuallyRequestedThisRound = 0;
                NSDate *nextResumeDate = [[dateToResumeRequesting dateByAddingTimeInterval:(60 * 60 * 4)] retain];
                [dateToResumeRequesting release];
                dateToResumeRequesting = nextResumeDate;
                HSLogDebug(@"reset next request resume date to %@", nextResumeDate);
            }
            
            // Make sure we've transferred all the bytes from all but the most recent round of requests.
            double theMinimum = (roundsCompleted = 0) ? 0 : ((double)bytesToRequestPerRound * (double)(roundsCompleted - 1)) * .9;
            unsigned long long minimumBytesToHaveTransferred = (unsigned long long)theMinimum;
            if ((bytesActuallyRequestedThisRound < bytesToRequestPerRound)
                && (bytesTransferred >= minimumBytesToHaveTransferred)
                && ([[NSDate date] earlierDate:dateToResumeRequesting] == dateToResumeRequesting)) {
                
                // Request more Glacier items.
                if (![self requestMoreGlacierItems:error]) {
                    ret = NO;
                    break;
                }
            }
            
            if ([glacierRequestItems count] == 0) {
                HSLogDebug(@"finished requesting");
                if ([delegate s3GlacierRestorerDidFinishRequesting]) {
                    SETNSERROR([self errorDomain], ERROR_ABORT_REQUESTED, @"cancel requested");
                    ret = NO;
                    break;
                }
            }
        }
        
        
        // Restore an item if possible.
        
        NSError *restoreError = nil;
        RestoreItem *restoreItem = [restoreItems objectAtIndex:0];
        restoredAnItem = YES;
        HSLogDebug(@"attempting to restore %@", restoreItem);
        if (![restoreItem restoreWithHardlinks:hardlinks restorer:self error:&restoreError]) {
            if ([restoreError isErrorWithDomain:[restoreItem errorDomain] code:ERROR_GLACIER_OBJECT_NOT_AVAILABLE]) {
                HSLogDebug(@"glacier object not available yet");
                restoredAnItem = NO;
            } else if ([restoreError isErrorWithDomain:[self errorDomain] code:ERROR_ABORT_REQUESTED]) {
                if (error != NULL) {
                    *error = restoreError;
                }
                ret = NO;
                break;
            } else {
                [delegate s3GlacierRestorerErrorMessage:[restoreError localizedDescription] didOccurForPath:[restoreItem path]];
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
        
        if (!restoredAnItem) {
            HSLogDebug(@"sleeping");
            
            for (NSUInteger i = 0; i < sleepCycles; i++) {
                if (![self addToBytesTransferred:0 error:error]) {
                    ret = NO;
                    break;
                }
                [NSThread sleepForTimeInterval:SLEEP_CYCLE_DURATION];
            }
            sleepCycles *= 2;
            if (sleepCycles > SLEEP_CYCLES_MAX) {
                sleepCycles = SLEEP_CYCLES_MAX;
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

- (BOOL)requestMoreGlacierItems:(NSError **)error {
    BOOL ret = YES;
    NSAutoreleasePool *pool = nil;
    while (bytesActuallyRequestedThisRound < bytesToRequestPerRound && [glacierRequestItems count] > 0) {
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


- (BOOL)addToBytesRequested:(unsigned long long)length actualBytesRequested:(unsigned long long)actualBytesRequested error:(NSError **)error {
    bytesRequested += length;
    bytesActuallyRequestedThisRound += actualBytesRequested;
    if ([delegate s3GlacierRestorerBytesRequestedDidChange:[NSNumber numberWithUnsignedLongLong:bytesRequested]]) {
        SETNSERROR([self errorDomain], ERROR_ABORT_REQUESTED, @"cancel requested");
        return NO;
    }
    return YES;
}
- (BOOL)addToTotalBytesToRequest:(unsigned long long)length error:(NSError **)error {
    totalBytesToRequest += length;
    if ([delegate s3GlacierRestorerTotalBytesToRequestDidChange:[NSNumber numberWithUnsignedLongLong:totalBytesToRequest]]) {
        SETNSERROR([self errorDomain], ERROR_ABORT_REQUESTED, @"cancel requested");
        return NO;
    }
    return YES;
}
- (BOOL)addToBytesTransferred:(unsigned long long)length error:(NSError **)error {
    bytesTransferred += length;
    if ([delegate s3GlacierRestorerBytesTransferredDidChange:[NSNumber numberWithUnsignedLongLong:bytesTransferred]]) {
        SETNSERROR([self errorDomain], ERROR_ABORT_REQUESTED, @"cancel requested");
        return NO;
    }
    return YES;
}
- (BOOL)addToTotalBytesToTransfer:(unsigned long long)length error:(NSError **)error {
    totalBytesToTransfer += length;
    if ([delegate s3GlacierRestorerTotalBytesToTransferDidChange:[NSNumber numberWithUnsignedLongLong:totalBytesToTransfer]]) {
        SETNSERROR([self errorDomain], ERROR_ABORT_REQUESTED, @"cancel requested");
        return NO;
    }
    return YES;
}


#pragma mark TargetConnectionDelegate
- (BOOL)targetConnectionShouldRetryOnTransientError:(NSError **)error {
    return YES;
}
@end
