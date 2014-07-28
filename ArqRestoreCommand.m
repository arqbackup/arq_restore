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

#import "ArqRestoreCommand.h"
#import "Target.h"
#import "AWSRegion.h"
#import "BackupSet.h"
#import "S3Service.h"
#import "UserAndComputer.h"
#import "Bucket.h"
#import "Repo.h"
#import "S3RestorerParamSet.h"
#import "Tree.h"
#import "Commit.h"
#import "BlobKey.h"
#import "S3Restorer.h"
#import "S3GlacierRestorerParamSet.h"
#import "S3GlacierRestorer.h"
#import "GlacierRestorerParamSet.h"
#import "GlacierRestorer.h"
#import "S3AuthorizationProvider.h"


@implementation ArqRestoreCommand
- (void)dealloc {
    [target release];
    [super dealloc];
}

- (NSString *)errorDomain {
    return @"ArqRestoreCommandErrorDomain";
}

- (BOOL)executeWithArgc:(int)argc argv:(const char **)argv error:(NSError **)error {
    NSMutableArray *args = [NSMutableArray array];
    for (int i = 0; i < argc; i++) {
        [args addObject:[[[NSString alloc] initWithBytes:argv[i] length:strlen(argv[i]) encoding:NSUTF8StringEncoding] autorelease]];
    }
    
    if ([args count] < 2) {
        SETNSERROR([self errorDomain], ERROR_USAGE, @"missing arguments");
        return NO;
    }
    
    int index = 1;
    if ([[args objectAtIndex:1] isEqualToString:@"-l"]) {
        if ([args count] < 4) {
            SETNSERROR([self errorDomain], ERROR_USAGE, @"missing arguments");
            return NO;
        }
        setHSLogLevel(hsLogLevelForName([args objectAtIndex:2]));
        index += 2;
    }
    
    NSString *cmd = [args objectAtIndex:index];
    
    int targetParamsIndex = index + 1;
    if ([cmd isEqualToString:@"listcomputers"]) {
        // Valid command, but no additional args.
        
    } else if ([cmd isEqualToString:@"listfolders"]) {
        if ((argc - targetParamsIndex) < 2) {
            SETNSERROR([self errorDomain], ERROR_USAGE, @"missing arguments for listfolders command");
            return NO;
        }
        targetParamsIndex += 2;
    } else if ([cmd isEqualToString:@"restore"]) {
        if ((argc - targetParamsIndex) < 4) {
            SETNSERROR([self errorDomain], ERROR_USAGE, @"missing arguments");
            return NO;
        }
        targetParamsIndex += 4;
    } else {
        SETNSERROR([self errorDomain], ERROR_USAGE, @"unknown command: %@", cmd);
        return NO;
    }
    
    if (targetParamsIndex >= argc) {
        SETNSERROR([self errorDomain], ERROR_USAGE, @"missing target type params");
        return NO;
    }
    target = [[self targetForParams:[args subarrayWithRange:NSMakeRange(targetParamsIndex, argc - targetParamsIndex)] error:error] retain];
    if (target == nil) {
        return NO;
    }
    
    if ([cmd isEqualToString:@"listcomputers"]) {
        if (![self listComputers:error]) {
            return NO;
        }
    } else if ([cmd isEqualToString:@"listfolders"]) {
        if (![self listBucketsForComputerUUID:[args objectAtIndex:index+1] encryptionPassword:[args objectAtIndex:index+2] error:error]) {
            return NO;
        }
    } else if ([cmd isEqualToString:@"restore"]) {
        if (![self restoreComputerUUID:[args objectAtIndex:index+1] bucketUUID:[args objectAtIndex:index+3] encryptionPassword:[args objectAtIndex:index+2] restoreBytesPerSecond:[args objectAtIndex:index+4] error:error]) {
            return NO;
        }
    } else {
        SETNSERROR([self errorDomain], ERROR_USAGE, @"unknown command: %@", cmd);
        return NO;
    }
    
    return YES;
}


#pragma mark internal
- (Target *)targetForParams:(NSArray *)theParams error:(NSError **)error {
    NSString *theTargetType = [theParams objectAtIndex:0];
    
    Target *ret = nil;
    if ([theTargetType isEqualToString:@"aws"]) {
        if ([theParams count] != 4) {
            SETNSERROR([self errorDomain], ERROR_USAGE, @"invalid aws parameters");
            return nil;
        }
        
        NSString *theAccessKey = [theParams objectAtIndex:1];
        NSString *theSecretKey = [theParams objectAtIndex:2];
        NSString *theBucketName = [theParams objectAtIndex:3];
        AWSRegion *awsRegion = [self awsRegionForAccessKey:theAccessKey secretKey:theSecretKey bucketName:theBucketName error:error];
        if (awsRegion == nil) {
            return nil;
        }
        NSURL *s3Endpoint = [awsRegion s3EndpointWithSSL:YES];
        int port = [[s3Endpoint port] intValue];
        NSString *portString = @"";
        if (port != 0) {
            portString = [NSString stringWithFormat:@":%d", port];
        }
        NSURL *targetEndpoint = [NSURL URLWithString:[NSString stringWithFormat:@"%@://%@@%@%@/%@", [s3Endpoint scheme], theAccessKey, [s3Endpoint host], portString, theBucketName]];
        ret = [[[Target alloc] initWithEndpoint:targetEndpoint secret:theSecretKey passphrase:nil] autorelease];
    } else if ([theTargetType isEqualToString:@"sftp"]) {
        if ([theParams count] != 6 && [theParams count] != 7) {
            SETNSERROR([self errorDomain], ERROR_USAGE, @"invalid sftp parameters");
            return nil;
        }
        
        NSString *hostname = [theParams objectAtIndex:1];
        int port = [[theParams objectAtIndex:2] intValue];
        NSString *path = [theParams objectAtIndex:3];
        NSString *username = [theParams objectAtIndex:4];
        NSString *secret = [theParams objectAtIndex:5];
        NSString *keyfilePassphrase = [theParams count] > 6 ? [theParams objectAtIndex:6] : nil;
        
        if (![path hasPrefix:@"/"]) {
            path = [@"/~/" stringByAppendingString:path];
        }
        NSString *escapedPath = (NSString *)CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef)path, NULL, (CFStringRef)@"!*'();:@&=+$,?%#[]", kCFStringEncodingUTF8);
        NSString *escapedUsername = (NSString *)CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef)username, NULL, (CFStringRef)@"!*'();:@&=+$,?%#[]", kCFStringEncodingUTF8);
        NSURL *endpoint = [NSURL URLWithString:[NSString stringWithFormat:@"sftp://%@@%@:%d%@", escapedUsername, hostname, port, escapedPath]];

        ret = [[[Target alloc] initWithEndpoint:endpoint secret:secret passphrase:keyfilePassphrase] autorelease];
    } else if ([theTargetType isEqualToString:@"greenqloud"]
               || [theTargetType isEqualToString:@"dreamobjects"]
               || [theTargetType isEqualToString:@"googlecloudstorage"]
               
               || [theTargetType isEqualToString:@"s3compatible"]) {
        if ([theParams count] != 4) {
            SETNSERROR([self errorDomain], ERROR_USAGE, @"invalid %@ parameters", theTargetType);
            return nil;
        }
        
        NSString *theAccessKey = [theParams objectAtIndex:1];
        NSString *theSecretKey = [theParams objectAtIndex:2];
        NSString *theBucketName = [theParams objectAtIndex:3];
        NSString *theHostname = nil;
        if ([theTargetType isEqualToString:@"greenqloud"]) {
            theHostname = @"s.greenqloud.com";
        } else if ([theTargetType isEqualToString:@"dreamobjects"]) {
            theHostname = @"objects.dreamhost.com";
        } else if ([theTargetType isEqualToString:@"googlecloudstorage"]) {
            theHostname = @"storage.googleapis.com";
        } else {
            SETNSERROR([self errorDomain], ERROR_USAGE, @"no hostname for target type: %@", theTargetType);
            return nil;
        }
        
        NSURL *endpoint = [NSURL URLWithString:[NSString stringWithFormat:@"https://%@@%@/%@", theAccessKey, theHostname, theBucketName]];
        ret = [[[Target alloc] initWithEndpoint:endpoint secret:theSecretKey passphrase:nil] autorelease];
    } else if ([theTargetType isEqualToString:@"googledrive"]) {
        if ([theParams count] != 3) {
            SETNSERROR([self errorDomain], ERROR_USAGE, @"invalid googledrive parameters");
            return nil;
        }
        
        NSString *theRefreshToken = [theParams objectAtIndex:1];
        NSString *thePath = [theParams objectAtIndex:2];
        
        NSString *escapedPath = (NSString *)CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (CFStringRef)thePath, CFSTR("/"), CFSTR("@?=&+"), kCFStringEncodingUTF8);
        [escapedPath autorelease];
        
        NSURL *endpoint = [NSURL URLWithString:[NSString stringWithFormat:@"googledrive://unknown_email_address@www.googleapis.com%@", escapedPath]];
        ret = [[[Target alloc] initWithEndpoint:endpoint secret:theRefreshToken passphrase:nil] autorelease];
    } else {
        SETNSERROR([self errorDomain], ERROR_USAGE, @"unknown target type: %@", theTargetType);
        return nil;
    }
    return ret;
}

- (AWSRegion *)awsRegionForAccessKey:(NSString *)theAccessKey secretKey:(NSString *)theSecretKey bucketName:(NSString *)theBucketName error:(NSError **)error {
    S3AuthorizationProvider *sap = [[[S3AuthorizationProvider alloc] initWithAccessKey:theAccessKey secretKey:theSecretKey] autorelease];
    NSURL *endpoint = [[AWSRegion usEast1] s3EndpointWithSSL:YES];
    S3Service *s3 = [[[S3Service alloc] initWithS3AuthorizationProvider:sap endpoint:endpoint useAmazonRRS:NO] autorelease];
    
    NSString *location = [s3 locationOfS3Bucket:theBucketName targetConnectionDelegate:nil error:error];
    if (location == nil) {
        return nil;
    }
    return [AWSRegion regionWithLocation:location];
}

- (BOOL)listComputers:(NSError **)error {
    NSArray *expandedTargetList = [self expandedTargetList:error];
    if (expandedTargetList == nil) {
        return NO;
    }
    
    NSMutableArray *ret = [NSMutableArray array];
    for (Target *theTarget in expandedTargetList) {
        NSError *myError = nil;
        HSLogDebug(@"getting backup sets for %@", theTarget);
        
        NSArray *backupSets = [BackupSet allBackupSetsForTarget:theTarget targetConnectionDelegate:nil error:&myError];
        if (backupSets == nil) {
            if ([myError isErrorWithDomain:[S3Service errorDomain] code:S3SERVICE_ERROR_AMAZON_ERROR] && [[[myError userInfo] objectForKey:@"HTTPStatusCode"] intValue] == 403) {
                HSLogError(@"access denied getting backup sets for %@", theTarget);
            } else {
                HSLogError(@"error getting backup sets for %@: %@", theTarget, myError);
                SETERRORFROMMYERROR;
                return nil;
            }
        } else {
            printf("target: %s\n", [[theTarget endpointDisplayName] UTF8String]);
            for (BackupSet *backupSet in backupSets) {
                printf("\tcomputer %s\n", [[backupSet computerUUID] UTF8String]);
                printf("\t\t%s (%s)\n", [[[backupSet userAndComputer] computerName] UTF8String], [[[backupSet userAndComputer] userName] UTF8String]);
            }
        }
    }
    return ret;
}
- (NSArray *)expandedTargetList:(NSError **)error {
    NSMutableArray *expandedTargetList = [NSMutableArray arrayWithObject:target];
//    if ([target targetType] == kTargetAWS
//        || [target targetType] == kTargetDreamObjects
//        || [target targetType] == kTargetGoogleCloudStorage
//        || [target targetType] == kTargetGreenQloud
//        || [target targetType] == kTargetS3Compatible) {
//        NSError *myError = nil;
//        NSArray *targets = [self expandedTargetsForS3Target:target error:&myError];
//        if (targets == nil) {
//            HSLogError(@"failed to expand target list for %@: %@", target, myError);
//        } else {
//            [expandedTargetList setArray:targets];
//            HSLogDebug(@"expandedTargetList is now: %@", expandedTargetList);
//        }
//    }
    return expandedTargetList;
}
- (NSArray *)expandedTargetsForS3Target:(Target *)theTarget error:(NSError **)error {
    S3Service *s3 = [theTarget s3:error];
    if (s3 == nil) {
        return nil;
    }
    NSArray *s3BucketNames = [s3 s3BucketNamesWithTargetConnectionDelegate:nil error:error];
    if (s3BucketNames == nil) {
        return nil;
    }
    HSLogDebug(@"s3BucketNames for %@: %@", theTarget, s3BucketNames);
    
    NSURL *originalEndpoint = [theTarget endpoint];
    NSMutableArray *ret = [NSMutableArray array];
    
    for (NSString *s3BucketName in s3BucketNames) {
        NSURL *endpoint = nil;
        if ([theTarget targetType] == kTargetAWS) {
            NSString *location = [s3 locationOfS3Bucket:s3BucketName targetConnectionDelegate:nil error:error];
            if (location == nil) {
                return nil;
            }
            AWSRegion *awsRegion = [AWSRegion regionWithLocation:location];
            HSLogDebug(@"awsRegion for s3BucketName %@: %@", s3BucketName, location);
            
            NSURL *s3Endpoint = [awsRegion s3EndpointWithSSL:YES];
            HSLogDebug(@"s3Endpoint: %@", s3Endpoint);
            endpoint = [NSURL URLWithString:[NSString stringWithFormat:@"https://%@@%@/%@", [originalEndpoint user], [s3Endpoint host], s3BucketName]];
        } else {
            endpoint = [NSURL URLWithString:[NSString stringWithFormat:@"%@://%@@%@/%@", [originalEndpoint scheme], [originalEndpoint user], [originalEndpoint host], s3BucketName]];
        }
        HSLogDebug(@"endpoint: %@", endpoint);
        
        Target *theTarget = [[[Target alloc] initWithEndpoint:endpoint secret:[theTarget secret:NULL] passphrase:[theTarget passphrase:NULL]] autorelease];
        [ret addObject:theTarget];
    }
    return ret;
}

- (BOOL)listBucketsForComputerUUID:(NSString *)theComputerUUID encryptionPassword:(NSString *)theEncryptionPassword error:(NSError **)error {
    NSArray *buckets = [Bucket bucketsWithTarget:target computerUUID:theComputerUUID encryptionPassword:theEncryptionPassword targetConnectionDelegate:nil error:error];
    if (buckets == nil) {
        return NO;
    }
    
    printf("target   %s\n", [[target endpointDisplayName] UTF8String]);
    printf("computer %s\n", [theComputerUUID UTF8String]);
    
    for (Bucket *bucket in buckets) {
        printf("\tfolder %s\n", [[bucket localPath] UTF8String]);
        printf("\t\tuuid %s\n", [[bucket bucketUUID] UTF8String]);
        
    }
    
    return YES;
}
- (BOOL)restoreComputerUUID:(NSString *)theComputerUUID bucketUUID:(NSString *)theBucketUUID encryptionPassword:(NSString *)theEncryptionPassword restoreBytesPerSecond:(NSString *)theRestoreBytesPerSecond error:(NSError **)error {
    Bucket *myBucket = nil;
    NSArray *expandedTargetList = [self expandedTargetList:error];
    if (expandedTargetList == nil) {
        return NO;
    }
    for (Target *theTarget in expandedTargetList) {
        NSArray *buckets = [Bucket bucketsWithTarget:theTarget computerUUID:theComputerUUID encryptionPassword:theEncryptionPassword targetConnectionDelegate:nil error:error];
        if (buckets == nil) {
            return NO;
        }
        for (Bucket *bucket in buckets) {
            if ([[bucket bucketUUID] isEqualToString:theBucketUUID]) {
                myBucket = bucket;
                break;
            }
        }
        
        if (myBucket != nil) {
            break;
        }
    }
    if (myBucket == nil) {
        SETNSERROR([self errorDomain], ERROR_NOT_FOUND, @"folder %@ not found", theBucketUUID);
        return NO;
    }
    
    Repo *repo = [[[Repo alloc] initWithBucket:myBucket encryptionPassword:theEncryptionPassword targetUID:getuid() targetGID:getgid() loadExistingMutablePackFiles:NO targetConnectionDelegate:nil repoDelegate:nil error:error] autorelease];
    if (repo == nil) {
        return NO;
    }
    
    
    BlobKey *commitBlobKey = [repo headBlobKey:error];
    if (commitBlobKey == nil) {
        return NO;
    }
    Commit *commit = [repo commitForBlobKey:commitBlobKey dataSize:NULL error:error];
    if (commit == nil) {
        return NO;
    }
    
    NSString *destinationPath = [[[NSFileManager defaultManager] currentDirectoryPath] stringByAppendingPathComponent:[[myBucket localPath] lastPathComponent]];
    if ([[NSFileManager defaultManager] fileExistsAtPath:destinationPath]) {
        SETNSERROR([self errorDomain], -1, @"%@ already exists", destinationPath);
        return NO;
    }
    
    
    printf("target   %s\n", [[[myBucket target] endpointDisplayName] UTF8String]);
    printf("computer %s\n", [[myBucket computerUUID] UTF8String]);
    printf("\nrestoring folder %s to %s\n\n", [[myBucket localPath] UTF8String], [destinationPath UTF8String]);
    
    AWSRegion *region = [AWSRegion regionWithS3Endpoint:[target endpoint]];
    BOOL isGlacierDestination = [region supportsGlacier];
    if ([myBucket storageType] == StorageTypeGlacier && isGlacierDestination) {
        int bytesPerSecond = [theRestoreBytesPerSecond intValue];
        if (bytesPerSecond == 0) {
            SETNSERROR([self errorDomain], -1, @"invalid bytes_per_second %@", theRestoreBytesPerSecond);
            return NO;
        }
        
        GlacierRestorerParamSet *paramSet = [[[GlacierRestorerParamSet alloc] initWithBucket:myBucket
                                                                          encryptionPassword:theEncryptionPassword
                                                                      downloadBytesPerSecond:bytesPerSecond
                                                                               commitBlobKey:commitBlobKey
                                                                                rootItemName:[[myBucket localPath] lastPathComponent]
                                                                                 treeVersion:CURRENT_TREE_VERSION
                                                                            treeIsCompressed:[[commit treeBlobKey] compressed]
                                                                                 treeBlobKey:[commit treeBlobKey]
                                                                                    nodeName:nil targetUID:getuid()
                                                                                   targetGID:getgid()
                                                                          useTargetUIDAndGID:YES
                                                                             destinationPath:destinationPath
                                                                                    logLevel:global_hslog_level] autorelease];
        [[[GlacierRestorer alloc] initWithGlacierRestorerParamSet:paramSet delegate:self] autorelease];
        
    } else if ([myBucket storageType] == StorageTypeS3Glacier && isGlacierDestination) {
        int bytesPerSecond = [theRestoreBytesPerSecond intValue];
        if (bytesPerSecond == 0) {
            SETNSERROR([self errorDomain], -1, @"invalid bytes_per_second %@", theRestoreBytesPerSecond);
            return NO;
        }
        
        S3GlacierRestorerParamSet *paramSet = [[[S3GlacierRestorerParamSet alloc] initWithBucket:myBucket
                                                                              encryptionPassword:theEncryptionPassword
                                                                          downloadBytesPerSecond:bytesPerSecond
                                                                                   commitBlobKey:commitBlobKey
                                                                                    rootItemName:[[myBucket localPath] lastPathComponent]
                                                                                     treeVersion:CURRENT_TREE_VERSION
                                                                                treeIsCompressed:[[commit treeBlobKey] compressed]
                                                                                     treeBlobKey:[commit treeBlobKey]
                                                                                        nodeName:nil
                                                                                       targetUID:getuid()
                                                                                       targetGID:getgid()
                                                                              useTargetUIDAndGID:YES
                                                                                 destinationPath:destinationPath
                                                                                        logLevel:global_hslog_level] autorelease];
        S3GlacierRestorer *restorer = [[[S3GlacierRestorer alloc] initWithS3GlacierRestorerParamSet:paramSet delegate:self] autorelease];
        [restorer run];
    } else {
        S3RestorerParamSet *paramSet = [[[S3RestorerParamSet alloc] initWithBucket:myBucket
                                                                encryptionPassword:theEncryptionPassword
                                                                     commitBlobKey:commitBlobKey
                                                                      rootItemName:[[myBucket localPath] lastPathComponent]
                                                                       treeVersion:CURRENT_TREE_VERSION
                                                                  treeIsCompressed:[[commit treeBlobKey] compressed]
                                                                       treeBlobKey:[commit treeBlobKey]
                                                                          nodeName:nil
                                                                         targetUID:getuid()
                                                                         targetGID:getgid()
                                                                useTargetUIDAndGID:YES
                                                                   destinationPath:destinationPath
                                                                          logLevel:global_hslog_level] autorelease];
        [[[S3Restorer alloc] initWithParamSet:paramSet delegate:self] autorelease];
    }
    
    return YES;
}


#pragma mark S3RestorerDelegate
// Methods return YES if cancel is requested.

- (BOOL)s3RestorerMessageDidChange:(NSString *)message {
    printf("status: %s\n", [message UTF8String]);
    return NO;
}
- (BOOL)s3RestorerBytesTransferredDidChange:(NSNumber *)theTransferred {
    return NO;
}
- (BOOL)s3RestorerTotalBytesToTransferDidChange:(NSNumber *)theTotal {
    return NO;
}
- (BOOL)s3RestorerErrorMessage:(NSString *)theErrorMessage didOccurForPath:(NSString *)thePath {
    printf("%s error: %s\n", [thePath UTF8String], [theErrorMessage UTF8String]);
    return NO;
}
- (BOOL)s3RestorerDidSucceed {
    return NO;
}
- (BOOL)s3RestorerDidFail:(NSError *)error {
    printf("failed: %s\n", [[error localizedDescription] UTF8String]);
    return NO;
}


#pragma mark S3GlacierRestorerDelegate
- (BOOL)s3GlacierRestorerMessageDidChange:(NSString *)message {
    printf("status: %s\n", [message UTF8String]);
    return NO;
}
- (BOOL)s3GlacierRestorerBytesRequestedDidChange:(NSNumber *)theRequested {
    printf("requested %qu of %qu\n", [theRequested unsignedLongLongValue], maxRequested);
    return NO;
}
- (BOOL)s3GlacierRestorerTotalBytesToRequestDidChange:(NSNumber *)theMaxRequested {
    maxRequested = [theMaxRequested unsignedLongLongValue];
    return NO;
}
- (BOOL)s3GlacierRestorerDidFinishRequesting {
    return NO;
}
- (BOOL)s3GlacierRestorerBytesTransferredDidChange:(NSNumber *)theTransferred {
    printf("restored %qu of %qu\n", [theTransferred unsignedLongLongValue], maxTransfer);
    return NO;
}
- (BOOL)s3GlacierRestorerTotalBytesToTransferDidChange:(NSNumber *)theTotal {
    maxTransfer = [theTotal unsignedLongLongValue];
    return NO;
}
- (BOOL)s3GlacierRestorerErrorMessage:(NSString *)theErrorMessage didOccurForPath:(NSString *)thePath {
    printf("%s error: %s\n", [thePath UTF8String], [theErrorMessage UTF8String]);
    return NO;
}
- (void)s3GlacierRestorerDidSucceed {
    printf("restore finished.\n");
}
- (void)s3GlacierRestorerDidFail:(NSError *)error {
    printf("failed: %s\n", [[error localizedDescription] UTF8String]);
}


#pragma mark GlacierRestorerDelegate
- (BOOL)glacierRestorerMessageDidChange:(NSString *)message {
    printf("status: %s\n", [message UTF8String]);
    return NO;
}
- (BOOL)glacierRestorerBytesRequestedDidChange:(NSNumber *)theRequested {
    return NO;
}
- (BOOL)glacierRestorerTotalBytesToRequestDidChange:(NSNumber *)theMaxRequested {
    return NO;
}
- (BOOL)glacierRestorerDidFinishRequesting {
    return NO;
}
- (BOOL)glacierRestorerBytesTransferredDidChange:(NSNumber *)theTransferred {
    return NO;
}
- (BOOL)glacierRestorerTotalBytesToTransferDidChange:(NSNumber *)theTotal {
    return NO;
}
- (BOOL)glacierRestorerErrorMessage:(NSString *)theErrorMessage didOccurForPath:(NSString *)thePath {
    printf("%s error: %s\n", [thePath UTF8String], [theErrorMessage UTF8String]);
    return NO;
}
- (BOOL)glacierRestorerDidSucceed {
    return NO;
}
- (BOOL)glacierRestorerDidFail:(NSError *)error {
    printf("failed: %s\n", [[error localizedDescription] UTF8String]);
    return NO;
}

@end
