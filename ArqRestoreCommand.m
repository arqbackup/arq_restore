/*
 Copyright (c) 2009-2017, Haystack Software LLC https://www.arqbackup.com
 
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


#include <termios.h>
#import "ArqRestoreCommand.h"
#import "Target.h"
#import "AWSRegion.h"
#import "BackupSet.h"
#import "S3Service.h"
#import "UserAndComputer.h"
#import "Bucket.h"
#import "Repo.h"
#import "StandardRestorerParamSet.h"
#import "Tree.h"
#import "Commit.h"
#import "Node.h"
#import "BlobKey.h"
#import "StandardRestorer.h"
#import "S3GlacierRestorerParamSet.h"
#import "S3GlacierRestorer.h"
#import "GlacierRestorerParamSet.h"
#import "GlacierRestorer.h"
#import "S3AuthorizationProvider.h"
#import "S3AuthorizationProviderFactory.h"
#import "NSString_extra.h"
#import "TargetFactory.h"
#import "RegexKitLite.h"
#import "BackupSet.h"
#import "ExePath.h"
#import "AWSRegion.h"


#define BUFSIZE (65536)


@implementation ArqRestoreCommand
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
    
    if ([args count] > 3 && [[args objectAtIndex:1] isEqualToString:@"-l"]) {
        [[HSLog sharedHSLog] setHSLogLevel:[HSLog hsLogLevelForName:[args objectAtIndex:2]]];
        args = [NSMutableArray arrayWithArray:[args subarrayWithRange:NSMakeRange(2, [args count] - 2)]];
    }
    
    NSString *cmd = [args objectAtIndex:1];
    
    if ([cmd isEqualToString:@"listtargets"]) {
        return [self listTargets:error];
    } else if ([cmd isEqualToString:@"addtarget"]) {
        return [self addTarget:args error:error];
    } else if ([cmd isEqualToString:@"deletetarget"]) {
        return [self deleteTarget:args error:error];
    } else if ([cmd isEqualToString:@"listcomputers"]) {
        return [self listComputers:args error:error];
    } else if ([cmd isEqualToString:@"listfolders"]) {
        return [self listFolders:args error:error];
    } else if ([cmd isEqualToString:@"printplist"]) {
        return [self printPlist:args error:error];
    } else if ([cmd isEqualToString:@"listtree"]) {
        return [self listTree:args error:error];
    } else if ([cmd isEqualToString:@"restore"]) {
        return [self restore:args error:error];
    } else if ([cmd isEqualToString:@"clearcache"]) {
        return [self clearCache:args error:error];
    } else {
        SETNSERROR([self errorDomain], ERROR_USAGE, @"unknown command: %@", cmd);
        return NO;
    }
    
    return YES;
}


#pragma mark internal
- (BOOL)listTargets:(NSError **)error {
    printf("%-20s %s\n", "nickname:", "url:");
    for (Target *target in [[TargetFactory sharedTargetFactory] sortedTargets]) {
        printf("%-20s %s\n", [[target nickname] UTF8String], [[[target endpoint] description] UTF8String]);
    }
    return YES;
}

- (BOOL)addTarget:(NSArray *)args error:(NSError **)error {
    if ([args count] < 5) {
        SETNSERROR([self errorDomain], ERROR_USAGE, @"missing arguments");
        return NO;
    }
    NSString *targetUUID = [NSString stringWithRandomUUID];
    NSString *targetNickname = [args objectAtIndex:2];
    NSString *targetType = [args objectAtIndex:3];
    
    NSURL *endpoint = nil;
    NSString *secret = nil;
    NSString *passphrase = nil;
    NSString *oAuth2ClientId = nil;
    NSString *oAuth2ClientSecret = nil;
    NSString *oAuth2RedirectURI = nil;
    
    if ([targetType isEqualToString:@"aws"]) {
        if ([args count] != 5) {
            SETNSERROR([self errorDomain], ERROR_USAGE, @"invalid arguments");
            return NO;
        }
        
        NSString *accessKeyId = [args objectAtIndex:4];
        AWSRegion *usEast1 = [AWSRegion usEast1];
        NSString *urlString = [NSString stringWithFormat:@"https://%@@%@/any_bucket", accessKeyId, [[usEast1 s3EndpointWithSSL:NO] host]];
        
        endpoint = [NSURL URLWithString:urlString];
        secret = [self readPasswordWithPrompt:@"enter AWS secret key:" error:error];
        if (secret == nil) {
            return NO;
        }
        
    } else if ([targetType isEqualToString:@"local"]) {
        if ([args count] != 5) {
            SETNSERROR([self errorDomain], ERROR_USAGE, @"invalid arguments");
            return NO;
        }
        
        endpoint = [NSURL fileURLWithPath:[args objectAtIndex:4]];
        secret = @"unused";
    } else {
        SETNSERROR([self errorDomain], -1, @"unknown target type: %@", targetType);
        return NO;
    }
    
    Target *target = [[[Target alloc] initWithUUID:targetUUID nickname:targetNickname endpoint:endpoint awsRequestSignatureVersion:4] autorelease];
    [target setOAuth2ClientId:oAuth2ClientId];
    [target setOAuth2RedirectURI:oAuth2RedirectURI];
    if (![[TargetFactory sharedTargetFactory] saveTarget:target error:error]) {
        return NO;
    }
    if (![target setSecret:secret trustedAppPaths:[NSArray arrayWithObject:[ExePath exePath]] error:error]) {
        return NO;
    }
    if (passphrase != nil) {
        if (![target setPassphrase:passphrase trustedAppPaths:[NSArray arrayWithObject:[ExePath exePath]] error:error]) {
            return NO;
        }
    }
    if (oAuth2ClientSecret != nil) {
        if (![target setOAuth2ClientSecret:oAuth2ClientSecret trustedAppPaths:[NSArray arrayWithObject:[ExePath exePath]] error:error]) {
            return NO;
        }
    }
    
    return YES;
}
- (BOOL)deleteTarget:(NSArray *)args error:(NSError **)error {
    if ([args count] != 3) {
        SETNSERROR([self errorDomain], ERROR_USAGE, @"invalid arguments");
        return NO;
    }
    Target *target = [[TargetFactory sharedTargetFactory] targetWithNickname:[args objectAtIndex:2]];
    if (target == nil) {
        SETNSERROR([self errorDomain], ERROR_NOT_FOUND, @"target not found");
        return NO;
    }
    TargetConnection *conn = [[target newConnection:error] autorelease];
    if (conn == nil) {
        return NO;
    }
    if (![conn clearAllCachedData:error]) {
        return NO;
    }

    return [[TargetFactory sharedTargetFactory] deleteTarget:target error:error];
}

- (BOOL)listComputers:(NSArray *)args error:(NSError **)error {
    if ([args count] != 3) {
        SETNSERROR([self errorDomain], ERROR_USAGE, @"invalid arguments");
        return NO;
    }
    Target *target = [[TargetFactory sharedTargetFactory] targetWithNickname:[args objectAtIndex:2]];
    if (target == nil) {
        SETNSERROR([self errorDomain], ERROR_NOT_FOUND, @"target not found");
        return NO;
    }
    NSArray *expandedTargetList = [self expandedTargetListForTarget:target error:error];
    if (expandedTargetList == nil) {
        return NO;
    }
    
    for (Target *theTarget in expandedTargetList) {
        NSError *myError = nil;
        HSLogDebug(@"getting backup sets for %@", theTarget);
        
        NSArray *backupSets = [BackupSet allBackupSetsForTarget:theTarget targetConnectionDelegate:nil activityListener:nil error:&myError];
        if (backupSets == nil) {
            if ([myError isErrorWithDomain:[S3Service errorDomain] code:S3SERVICE_ERROR_AMAZON_ERROR] && [[[myError userInfo] objectForKey:@"HTTPStatusCode"] intValue] == 403) {
                HSLogError(@"access denied getting backup sets for %@", theTarget);
            } else {
                HSLogError(@"error getting backup sets for %@: %@", theTarget, myError);
                SETERRORFROMMYERROR;
                return NO;
            }
        } else {
            printf("target: %s\n", [[theTarget endpointDisplayName] UTF8String]);
            for (BackupSet *backupSet in backupSets) {
                printf("\tcomputer %s\n", [[backupSet computerUUID] UTF8String]);
                printf("\t\t%s (%s)\n", [[[backupSet userAndComputer] computerName] UTF8String], [[[backupSet userAndComputer] userName] UTF8String]);
            }
        }
    }
    return YES;
}


- (BOOL)listFolders:(NSArray *)args error:(NSError **)error {
    if ([args count] != 4) {
        SETNSERROR([self errorDomain], ERROR_USAGE, @"invalid arguments");
        return NO;
    }
    Target *target = [[TargetFactory sharedTargetFactory] targetWithNickname:[args objectAtIndex:2]];
    if (target == nil) {
        SETNSERROR([self errorDomain], ERROR_NOT_FOUND, @"target not found");
        return NO;
    }
    
    NSString *theComputerUUID = [args objectAtIndex:3];
    NSString *theEncryptionPassword = [self readPasswordWithPrompt:@"enter encryption password:" error:error];
    if (theEncryptionPassword == nil) {
        return NO;
    }
    
    BackupSet *backupSet = [self backupSetForTarget:target computerUUID:theComputerUUID error:error];
    if (backupSet == nil) {
        return NO;
    }
    
    // Reset Target:
    target = [backupSet target];
    
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
- (BOOL)printPlist:(NSArray *)args error:(NSError **)error {
    if ([args count] != 5) {
        SETNSERROR([self errorDomain], ERROR_USAGE, @"invalid arguments");
        return NO;
    }
    Target *target = [[TargetFactory sharedTargetFactory] targetWithNickname:[args objectAtIndex:2]];
    if (target == nil) {
        SETNSERROR([self errorDomain], ERROR_NOT_FOUND, @"target not found");
        return NO;
    }
    
    NSString *theComputerUUID = [args objectAtIndex:3];
    NSString *theBucketUUID = [args objectAtIndex:4];
    
    NSString *theEncryptionPassword = [self readPasswordWithPrompt:@"enter encryption password:" error:error];
    if (theEncryptionPassword == nil) {
        return NO;
    }
    
    BackupSet *backupSet = [self backupSetForTarget:target computerUUID:theComputerUUID error:error];
    if (backupSet == nil) {
        return NO;
    }
    
    // Reset Target:
    target = [backupSet target];
    
    NSArray *buckets = [Bucket bucketsWithTarget:target computerUUID:theComputerUUID encryptionPassword:theEncryptionPassword targetConnectionDelegate:nil error:error];
    if (buckets == nil) {
        return NO;
    }
    Bucket *matchingBucket = nil;
    for (Bucket *bucket in buckets) {
        if ([[bucket bucketUUID] isEqualToString:theBucketUUID]) {
            matchingBucket = bucket;
            break;
        }
    }
    if (matchingBucket == nil) {
        SETNSERROR([self errorDomain], ERROR_NOT_FOUND, @"folder %@ not found", theBucketUUID);
        return NO;
    }
    
    printf("target   %s\n", [[target endpointDisplayName] UTF8String]);
    printf("computer %s\n", [theComputerUUID UTF8String]);
    printf("folder   %s\n", [theBucketUUID UTF8String]);
    
    NSData *xmlData = [matchingBucket toXMLData];
    NSString *xmlString = [[[NSString alloc] initWithData:xmlData encoding:NSUTF8StringEncoding] autorelease];
    printf("%s\n", [xmlString UTF8String]);
    return YES;
}
- (BOOL)listTree:(NSArray *)args error:(NSError **)error {
    if ([args count] != 5) {
        SETNSERROR([self errorDomain], ERROR_USAGE, @"invalid arguments");
        return NO;
    }
    Target *target = [[TargetFactory sharedTargetFactory] targetWithNickname:[args objectAtIndex:2]];
    if (target == nil) {
        SETNSERROR([self errorDomain], ERROR_NOT_FOUND, @"target not found");
        return NO;
    }
    
    NSString *theComputerUUID = [args objectAtIndex:3];
    NSString *theBucketUUID = [args objectAtIndex:4];

    NSString *theEncryptionPassword = [self readPasswordWithPrompt:@"enter encryption password:" error:error];
    if (theEncryptionPassword == nil) {
        return NO;
    }
    
    BackupSet *backupSet = [self backupSetForTarget:target computerUUID:theComputerUUID error:error];
    if (backupSet == nil) {
        return NO;
    }
    
    // Reset Target:
    target = [backupSet target];
    
    NSArray *buckets = [Bucket bucketsWithTarget:target computerUUID:theComputerUUID encryptionPassword:theEncryptionPassword targetConnectionDelegate:nil error:error];
    if (buckets == nil) {
        return NO;
    }
    Bucket *matchingBucket = nil;
    for (Bucket *bucket in buckets) {
        if ([[bucket bucketUUID] isEqualToString:theBucketUUID]) {
            matchingBucket = bucket;
            break;
        }
    }
    if (matchingBucket == nil) {
        SETNSERROR([self errorDomain], ERROR_NOT_FOUND, @"folder %@ not found", theBucketUUID);
        return NO;
    }
    
    printf("target   %s\n", [[target endpointDisplayName] UTF8String]);
    printf("computer %s\n", [theComputerUUID UTF8String]);
    printf("folder   %s\n", [theBucketUUID UTF8String]);
    
    Repo *repo = [[[Repo alloc] initWithBucket:matchingBucket encryptionPassword:theEncryptionPassword targetConnectionDelegate:nil repoDelegate:nil activityListener:nil error:error] autorelease];
    if (repo == nil) {
        return NO;
    }
    BlobKey *headBlobKey = [repo headBlobKey:error];
    if (headBlobKey == nil) {
        return NO;
    }
    Commit *head = [repo commitForBlobKey:headBlobKey error:error];
    if (head == nil) {
        return NO;
    }
    Tree *rootTree = [repo treeForBlobKey:[head treeBlobKey] error:error];
    if (rootTree == nil) {
        return NO;
    }
    return [self printTree:rootTree repo:repo relativePath:@"" error:error];
}
- (BOOL)printTree:(Tree *)theTree repo:(Repo *)theRepo relativePath:(NSString *)theRelativePath error:(NSError **)error {
    for (NSString *childName in [theTree childNodeNames]) {
        NSString *childRelativePath = [theRelativePath stringByAppendingFormat:@"/%@", childName];
        Node *childNode = [theTree childNodeWithName:childName];
        if ([childNode isTree]) {
            printf("%s:\n", [childRelativePath UTF8String]);
            Tree *childTree = [theRepo treeForBlobKey:[childNode treeBlobKey] error:error];
            if (childTree == nil) {
                return NO;
            }
            if (![self printTree:childTree
                            repo:theRepo
                    relativePath:childRelativePath
                           error:error]) {
                return NO;
            }
        } else {
            printf("%s\n", [childRelativePath UTF8String]);
        }
    }
    return YES;
}

- (BOOL)restore:(NSArray *)args error:(NSError **)error {
    if ([args count] != 5 && [args count] != 6) {
        SETNSERROR([self errorDomain], ERROR_USAGE, @"invalid arguments");
        return NO;
    }
    Target *target = [[TargetFactory sharedTargetFactory] targetWithNickname:[args objectAtIndex:2]];
    if (target == nil) {
        SETNSERROR([self errorDomain], ERROR_NOT_FOUND, @"target not found");
        return NO;
    }
    
    NSString *theComputerUUID = [args objectAtIndex:3];
    NSString *theBucketUUID = [args objectAtIndex:4];
    
    NSString *theEncryptionPassword = [self readPasswordWithPrompt:@"enter encryption password:" error:error];
    if (theEncryptionPassword == nil) {
        return NO;
    }
    
    BackupSet *backupSet = [self backupSetForTarget:target computerUUID:theComputerUUID error:error];
    if (backupSet == nil) {
        return NO;
    }
    
    // Reset Target:
    target = [backupSet target];
    
    NSArray *buckets = [Bucket bucketsWithTarget:target computerUUID:theComputerUUID encryptionPassword:theEncryptionPassword targetConnectionDelegate:nil error:error];
    if (buckets == nil) {
        return NO;
    }
    Bucket *matchingBucket = nil;
    for (Bucket *bucket in buckets) {
        if ([[bucket bucketUUID] isEqualToString:theBucketUUID]) {
            matchingBucket = bucket;
            break;
        }
    }
    if (matchingBucket == nil) {
        SETNSERROR([self errorDomain], ERROR_NOT_FOUND, @"folder %@ not found", theBucketUUID);
        return NO;
    }
    
    printf("target   %s\n", [[target endpointDisplayName] UTF8String]);
    printf("computer %s\n", [theComputerUUID UTF8String]);
    printf("folder   %s\n", [theBucketUUID UTF8String]);
    
    Repo *repo = [[[Repo alloc] initWithBucket:matchingBucket encryptionPassword:theEncryptionPassword targetConnectionDelegate:nil repoDelegate:nil activityListener:nil error:error] autorelease];
    if (repo == nil) {
        return NO;
    }
    BlobKey *commitBlobKey = [repo headBlobKey:error];
    if (commitBlobKey == nil) {
        return NO;
    }
    Commit *commit = [repo commitForBlobKey:commitBlobKey error:error];
    if (commit == nil) {
        return NO;
    }

    BlobKey *treeBlobKey = [commit treeBlobKey];
    NSString *nodeName = nil;
    if ([args count] == 6) {
        NSString *path = [args objectAtIndex:5];
        if ([path hasPrefix:@"/"]) {
            path = [path substringFromIndex:1];
        }
        NSArray *pathComponents = [path pathComponents];
        for (NSUInteger index = 0; index < [pathComponents count]; index++) {
            NSString *component = [pathComponents objectAtIndex:index];
            Tree *childTree = [repo treeForBlobKey:treeBlobKey error:error];
            if (childTree == nil) {
                return NO;
            }
            Node *childNode = [childTree childNodeWithName:component];
            if (childNode == nil) {
                SETNSERROR([self errorDomain], ERROR_NOT_FOUND, @"path component '%@' not found", component);
                return NO;
            }
            if (![childNode isTree] && index < ([pathComponents count] - 1)) {
                // If it's a directory and we're not at the end of the path, fail.
                SETNSERROR([self errorDomain], -1, @"'%@' is not a directory", component);
                return NO;
            }
            if ([childNode isTree]) {
                treeBlobKey = [childNode treeBlobKey];
            } else {
                nodeName = component;
            }
        }
    } else {
        Tree *rootTree = [repo treeForBlobKey:[commit treeBlobKey] error:error];
        if (rootTree == nil) {
            return NO;
        }
        if ([[rootTree childNodeNames] isEqualToArray:[NSArray arrayWithObject:@"."]]) {
            // Single-file case.
            nodeName = [[commit location] lastPathComponent];
        }
    }

    NSString *restoreFileName = [args count] == 6 ? [[args objectAtIndex:5] lastPathComponent] : [[matchingBucket localPath] lastPathComponent];
    NSString *destinationPath = [[[NSFileManager defaultManager] currentDirectoryPath] stringByAppendingPathComponent:restoreFileName];
    if ([[NSFileManager defaultManager] fileExistsAtPath:destinationPath]) {
        SETNSERROR([self errorDomain], -1, @"%@ already exists", destinationPath);
        return NO;
    }
    
    
    printf("\nrestoring folder %s to %s\n\n", [[matchingBucket localPath] UTF8String], [destinationPath UTF8String]);
    
    int bytesPerSecond = 500000;
    
    AWSRegion *region = [AWSRegion regionWithS3Endpoint:[target endpoint]];
    BOOL isGlacierDestination = [region supportsGlacier];
    if ([matchingBucket storageType] == StorageTypeGlacier && isGlacierDestination) {
        GlacierRestorerParamSet *paramSet = [[[GlacierRestorerParamSet alloc] initWithBucket:matchingBucket
                                                                          encryptionPassword:theEncryptionPassword
                                                                      downloadBytesPerSecond:bytesPerSecond
                                                                        glacierRetrievalTier:GLACIER_RETRIEVAL_TIER_EXPEDITED
                                                                               commitBlobKey:commitBlobKey
                                                                                rootItemName:[[matchingBucket localPath] lastPathComponent]
                                                                                 treeVersion:CURRENT_TREE_VERSION
                                                                                 treeBlobKey:treeBlobKey
                                                                                    nodeName:nodeName
                                                                                   targetUID:getuid()
                                                                                   targetGID:getgid()
                                                                          useTargetUIDAndGID:YES
                                                                             destinationPath:destinationPath
                                                                                    logLevel:[[HSLog sharedHSLog] hsLogLevel]] autorelease];
        [[[GlacierRestorer alloc] initWithGlacierRestorerParamSet:paramSet delegate:self] autorelease];
        
    } else if ([matchingBucket storageType] == StorageTypeS3Glacier && isGlacierDestination) {
        S3GlacierRestorerParamSet *paramSet = [[[S3GlacierRestorerParamSet alloc] initWithBucket:matchingBucket
                                                                              encryptionPassword:theEncryptionPassword
                                                                          downloadBytesPerSecond:bytesPerSecond
                                                                            glacierRetrievalTier:GLACIER_RETRIEVAL_TIER_EXPEDITED
                                                                                   commitBlobKey:commitBlobKey
                                                                                    rootItemName:[[matchingBucket localPath] lastPathComponent]
                                                                                     treeVersion:CURRENT_TREE_VERSION
                                                                                     treeBlobKey:treeBlobKey
                                                                                        nodeName:nodeName
                                                                                       targetUID:getuid()
                                                                                       targetGID:getgid()
                                                                              useTargetUIDAndGID:YES
                                                                                 destinationPath:destinationPath
                                                                                        logLevel:[[HSLog sharedHSLog] hsLogLevel]] autorelease];
        S3GlacierRestorer *restorer = [[[S3GlacierRestorer alloc] initWithS3GlacierRestorerParamSet:paramSet delegate:self] autorelease];
        [restorer run];
    } else {
        StandardRestorerParamSet *paramSet = [[[StandardRestorerParamSet alloc] initWithBucket:matchingBucket
                                                                            encryptionPassword:theEncryptionPassword
                                                                                 commitBlobKey:commitBlobKey
                                                                                  rootItemName:[[matchingBucket localPath] lastPathComponent]
                                                                                   treeVersion:CURRENT_TREE_VERSION
                                                                                   treeBlobKey:treeBlobKey
                                                                                      nodeName:nodeName
                                                                                     targetUID:getuid()
                                                                                     targetGID:getgid()
                                                                            useTargetUIDAndGID:YES
                                                                               destinationPath:destinationPath
                                                                                      logLevel:[[HSLog sharedHSLog] hsLogLevel]] autorelease];
        [[[StandardRestorer alloc] initWithParamSet:paramSet delegate:self] autorelease];
    }
    
    return YES;
}
- (BOOL)clearCache:(NSArray *)args error:(NSError **)error {
    if ([args count] != 3) {
        SETNSERROR([self errorDomain], ERROR_USAGE, @"invalid arguments");
        return NO;
    }
    Target *target = [[TargetFactory sharedTargetFactory] targetWithNickname:[args objectAtIndex:2]];
    if (target == nil) {
        SETNSERROR([self errorDomain], ERROR_NOT_FOUND, @"target not found");
        return NO;
    }
    TargetConnection *conn = [[target newConnection:error] autorelease];
    if (conn == nil) {
        return NO;
    }
    return [conn clearAllCachedData:error];
}



- (BackupSet *)backupSetForTarget:(Target *)theInitialTarget computerUUID:(NSString *)theComputerUUID error:(NSError **)error {
    NSArray *expandedTargetList = [self expandedTargetListForTarget:theInitialTarget error:error];
    if (expandedTargetList == nil) {
        return nil;
    }
    
    for (Target *theTarget in expandedTargetList) {
        NSError *myError = nil;
        NSArray *backupSets = [BackupSet allBackupSetsForTarget:theTarget targetConnectionDelegate:nil activityListener:nil error:&myError];
        if (backupSets == nil) {
            if ([myError isErrorWithDomain:[S3Service errorDomain] code:S3SERVICE_ERROR_AMAZON_ERROR] && [[[myError userInfo] objectForKey:@"HTTPStatusCode"] intValue] == 403) {
                HSLogError(@"access denied getting backup sets for %@", theTarget);
            } else {
                HSLogError(@"error getting backup sets for %@: %@", theTarget, myError);
                SETERRORFROMMYERROR;
                return nil;
            }
        } else {
            for (BackupSet *backupSet in backupSets) {
                if ([[backupSet computerUUID] isEqualToString:theComputerUUID]) {
                    return backupSet;
                }
            }
        }
    }
    SETNSERROR([self errorDomain], ERROR_NOT_FOUND, @"backup set %@ not found at target\n", theComputerUUID);
    return nil;
}

- (NSArray *)expandedTargetListForTarget:(Target *)theTarget error:(NSError **)error {
    NSArray *targets = nil;
    
    if ([theTarget targetType] == kTargetAWS) {
        targets = [self expandedTargetsForS3Target:theTarget error:error];
    } else {
        targets = [NSArray arrayWithObject:theTarget];
    }
    return targets;
}
- (NSArray *)expandedTargetsForS3Target:(Target *)theTarget error:(NSError **)error {
    NSString *theSecretKey = [theTarget secret:error];
    if (theSecretKey == nil) {
        return nil;
    }
    S3Service *s3 = nil;
    if ([AWSRegion regionWithS3Endpoint:[theTarget endpoint]] != nil) {
        // It's S3. Get bucket name list from us-east-1 region.
        NSURL *usEast1Endpoint = [[AWSRegion usEast1] s3EndpointWithSSL:YES];
        id <S3AuthorizationProvider> sap = [[S3AuthorizationProviderFactory sharedS3AuthorizationProviderFactory] providerForEndpoint:usEast1Endpoint
                                                                                                                            accessKey:[[theTarget endpoint] user]
                                                                                                                            secretKey:theSecretKey
                                                                                                                     signatureVersion:4
                                                                                                                            awsRegion:[AWSRegion usEast1]];
        s3 = [[[S3Service alloc] initWithS3AuthorizationProvider:sap endpoint:usEast1Endpoint] autorelease];
    } else {
        s3 = [theTarget s3:error];
        if (s3 == nil) {
            return nil;
        }
    }
    NSArray *s3BucketNames = [s3 s3BucketNamesWithTargetConnectionDelegate:nil error:error];
    if (s3BucketNames == nil) {
        return nil;
    }
    HSLogDebug(@"s3BucketNames for %@: %@", theTarget, s3BucketNames);
    
    NSURL *originalEndpoint = [theTarget endpoint];
    NSMutableArray *ret = [NSMutableArray array];
    
    // WARNING: This is a hack! We're creating this Target using the same UUID so that the keychain lookups work!
    NSString *targetUUID = [theTarget targetUUID];
    
    for (NSString *s3BucketName in s3BucketNames) {
        NSURL *endpoint = nil;
        if ([theTarget targetType] == kTargetAWS) {
            NSError *myError = nil;
            NSString *location = [s3 locationOfS3Bucket:s3BucketName targetConnectionDelegate:nil error:&myError];
            if (location == nil) {
                HSLogError(@"failed to get location of %@: %@", s3BucketName, myError);
            } else {
                AWSRegion *awsRegion = [AWSRegion regionWithLocation:location];
                HSLogDebug(@"awsRegion for s3BucketName %@: %@", s3BucketName, location);
                
                NSURL *s3Endpoint = [awsRegion s3EndpointWithSSL:YES];
                HSLogDebug(@"s3Endpoint: %@", s3Endpoint);
                endpoint = [NSURL URLWithString:[NSString stringWithFormat:@"https://%@@%@/%@", [originalEndpoint user], [s3Endpoint host], s3BucketName]];
            }
        } else {
            NSNumber *originalPort = [originalEndpoint port];
            NSString *portString = (originalPort == nil) ? @"" : [NSString stringWithFormat:@":%d", [originalPort intValue]];
            endpoint = [NSURL URLWithString:[NSString stringWithFormat:@"%@://%@@%@%@/%@", [originalEndpoint scheme], [originalEndpoint user], [originalEndpoint host], portString, s3BucketName]];
        }
        
        if (endpoint != nil) {
            HSLogDebug(@"endpoint: %@", endpoint);
            
            Target *target = [[[Target alloc] initWithUUID:targetUUID
                                                  nickname:s3BucketName
                                                  endpoint:endpoint
                                awsRequestSignatureVersion:[theTarget awsRequestSignatureVersion]] autorelease];
            [ret addObject:target];
        }
    }
    return ret;
}


#pragma mark StandardRestorerDelegate
// Methods return YES if cancel is requested.

- (BOOL)standardRestorerMessageDidChange:(NSString *)message {
    printf("status: %s\n", [message UTF8String]);
    return NO;
}
- (BOOL)standardRestorerFileBytesRestoredDidChange:(NSNumber *)theTransferred {
    return NO;
}
- (BOOL)standardRestorerTotalFileBytesToRestoreDidChange:(NSNumber *)theTotal {
    return NO;
}
- (BOOL)standardRestorerErrorMessage:(NSString *)theErrorMessage didOccurForPath:(NSString *)thePath {
    printf("%s error: %s\n", [thePath UTF8String], [theErrorMessage UTF8String]);
    return NO;
}
- (BOOL)standardRestorerDidSucceed {
    return NO;
}
- (BOOL)standardRestorerDidFail:(NSError *)error {
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


#pragma mark internal
- (NSString *)readPasswordWithPrompt:(NSString *)thePrompt error:(NSError **)error {
    fprintf(stderr, "%s ", [thePrompt UTF8String]);
    fflush(stderr);
    
    struct termios oldTermios;
    struct termios newTermios;
    
    if (tcgetattr(STDIN_FILENO, &oldTermios) != 0) {
        int errnum = errno;
        HSLogError(@"tcgetattr error %d: %s", errnum, strerror(errnum));
        SETNSERROR(@"UnixErrorDomain", errnum, @"%s", strerror(errnum));
        return nil;
    }
    newTermios = oldTermios;
    newTermios.c_lflag &= ~(ICANON | ECHO);
    tcsetattr(STDIN_FILENO, TCSANOW, &newTermios);
    size_t bufsize = BUFSIZE;
    char *buf = malloc(bufsize);
    ssize_t len = getline(&buf, &bufsize, stdin);
    free(buf);
    tcsetattr(STDIN_FILENO, TCSANOW, &oldTermios);
    
    if (len > 0 && buf[len - 1] == '\n') {
        --len;
    }
    
    return [[[NSString alloc] initWithBytes:buf length:len encoding:NSUTF8StringEncoding] autorelease];
}
@end
