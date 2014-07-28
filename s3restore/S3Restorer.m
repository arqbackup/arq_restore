//
//  S3Restorer.m
//  Arq
//
//  Created by Stefan Reitshamer on 5/28/13.
//  Copyright (c) 2013 Stefan Reitshamer. All rights reserved.
//

#import "S3Restorer.h"
#import "S3RestorerDelegate.h"
#import "ArqSalt.h"
#import "Repo.h"
#import "S3AuthorizationProvider.h"
#import "S3Service.h"
#import "Tree.h"
#import "Node.h"
#import "FileOutputStream.h"
#import "Commit.h"
#import "BlobKey.h"
#import "NSFileManager_extra.h"
#import "NSData-GZip.h"
#import "BufferedOutputStream.h"
#import "OSStatusDescription.h"
#import "FileAttributes.h"
#import "FileACL.h"
#import "DataInputStream.h"
#import "XAttrSet.h"
#import "FileInputStream.h"
#import "SHA1Hash.h"
#import "S3RestorerParamSet.h"
#import "RestoreItem.h"
#import "UserLibrary_Arq.h"
#import "CalculateItem.h"


@implementation S3Restorer
- (id)initWithParamSet:(S3RestorerParamSet *)theParamSet
              delegate:(id <S3RestorerDelegate>)theDelegate {
    if (self = [super init]) {
        paramSet = [theParamSet retain];
        delegate = theDelegate; // Don't retain it.
        
        skipFilesRoot = [[[UserLibrary arqUserLibraryPath] stringByAppendingFormat:@"/RestoreJobSkipFiles/%f", [NSDate timeIntervalSinceReferenceDate]] retain];

        calculateItems = [[NSMutableArray alloc] init];
        restoreItems = [[NSMutableArray alloc] init];
        hardlinks = [[NSMutableDictionary alloc] init];
        
        [self run];
    }
    return self;
}
- (void)dealloc {
    [paramSet release];
    
    [skipFilesRoot release];
    
    [calculateItems release];
    [restoreItems release];
    [hardlinks release];
    [repo release];
    [super dealloc];
}
- (void)run {
    NSError *myError = nil;
    if (![self run:&myError]) {
        [delegate s3RestorerDidFail:myError];
    } else {
        [delegate s3RestorerDidSucceed];
    }
}
- (BOOL)requestBlobKey:(BlobKey *)theBlobKey error:(NSError **)error {
    // Not relevant for S3.
    return YES;
}
- (NSNumber *)isObjectAvailableForBlobKey:(BlobKey *)theBlobKey error:(NSError **)error {
    return [NSNumber numberWithBool:YES];
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
    // Because of a bug in Arq pre-4.4, Arq might have created Buckets for non-AWS S3-compatible destinations with a storage type of StorageTypeS3Glacier.
    // So, we could be here and theBlobKey's storage type could be StorageTypeS3Glacier, which is OK because the Repo will just put "glacier/" in the path
    // and restoring will work fine.
    
    NSData *ret = [repo dataForBlobKey:theBlobKey error:error];
    if (ret == nil) {
        return nil;
    }
    if (![self addToBytesTransferred:[ret length] error:error]) {
        return nil;
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
- (NSString *)errorDomain {
    return @"S3RestorerErrorDomain";
}

- (BOOL)run:(NSError **)error {
    if (![self setUp:error]) {
        return NO;
    }
    
    if ([delegate s3RestorerMessageDidChange:@"Calculating sizes"]) {
        SETNSERROR([self errorDomain], ERROR_ABORT_REQUESTED, @"cancel requested");
        return NO;
    }
    if (![self calculateSizes:error]) {
        return NO;
    }
    
    if ([delegate s3RestorerMessageDidChange:[NSString stringWithFormat:@"Restoring %@ from %@ to %@", paramSet.rootItemName, commitDescription, paramSet.destinationPath]]) {
        SETNSERROR([self errorDomain], ERROR_ABORT_REQUESTED, @"cancel requested");
        return NO;
    }
    
    NSAutoreleasePool *pool = nil;
    BOOL ret = YES;
    while ([restoreItems count] > 0) {
        [pool drain];
        pool = [[NSAutoreleasePool alloc] init];
        
        RestoreItem *restoreItem = [restoreItems objectAtIndex:0];
        NSError *restoreError = nil;
        if (![restoreItem restoreWithHardlinks:hardlinks restorer:self error:&restoreError]) {
            if ([restoreError isErrorWithDomain:[self errorDomain] code:ERROR_ABORT_REQUESTED]) {
                if (error != NULL) {
                    *error = restoreError;
                }
                ret = NO;
                break;
            } else {
                [delegate s3RestorerErrorMessage:[restoreError localizedDescription] didOccurForPath:[restoreItem path]];
            }
        }
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

    unsigned long long total = 0;
    if (paramSet.nodeName != nil) {
        // Individual file.
        Node *node = [rootTree childNodeWithName:paramSet.nodeName];
        if ([[rootTree childNodeNames] isEqualToArray:[NSArray arrayWithObject:@"."]]) {
            // The single-file case.
            node = [rootTree childNodeWithName:@"."];
        }
        NSAssert(node != nil, @"node may not be nil");
        total = [node uncompressedDataSize];
        [calculateItems addObject:[[[CalculateItem alloc] initWithPath:paramSet.destinationPath node:node] autorelease]];
        [restoreItems addObject:[[[RestoreItem alloc] initWithPath:paramSet.destinationPath tree:rootTree node:node] autorelease]];
    } else {
        // Tree.
        total = [rootTree aggregateUncompressedDataSize];
        [calculateItems addObject:[[[CalculateItem alloc] initWithPath:paramSet.destinationPath tree:rootTree] autorelease]];
        [restoreItems addObject:[[[RestoreItem alloc] initWithPath:paramSet.destinationPath tree:rootTree] autorelease]];
    }
    if (![self addToTotalBytesToTransfer:total error:error]) {
        return NO;
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
- (BOOL)addToBytesTransferred:(unsigned long long)length error:(NSError **)error {
    bytesTransferred += length;
    if ([delegate s3RestorerBytesTransferredDidChange:[NSNumber numberWithUnsignedLongLong:bytesTransferred]]) {
        SETNSERROR([self errorDomain], ERROR_ABORT_REQUESTED, @"cancel requested");
        return NO;
    }
    return YES;
}
- (BOOL)addToTotalBytesToTransfer:(unsigned long long)length error:(NSError **)error {
    totalBytesToTransfer += length;
    if ([delegate s3RestorerTotalBytesToTransferDidChange:[NSNumber numberWithUnsignedLongLong:totalBytesToTransfer]]) {
        SETNSERROR([self errorDomain], ERROR_ABORT_REQUESTED, @"cancel requested");
        return NO;
    }
    return YES;
}
@end
