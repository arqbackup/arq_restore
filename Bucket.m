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



#import "Bucket.h"
#import "DictNode.h"
#import "ArrayNode.h"
#import "StringNode.h"
#import "BooleanNode.h"
#import "NSString_slashed.h"
#import "BucketExcludeSet.h"
#import "S3AuthorizationProvider.h"
#import "S3Service.h"
#import "UserLibrary_Arq.h"
#import "S3Service.h"
#import "FSStat.h"
#import "Volume.h"
#import "StorageType.h"
#import "GlacierService.h"
#import "AWSRegion.h"
#import "RegexKitLite.h"
#import "AWSRegion.h"
#import "ObjectEncryptor.h"
#import "Target.h"
#import "TargetConnection.h"
#import "GlacierAuthorizationProvider.h"
#import "GlacierService.h"
#import "DataIO.h"
#import "StringIO.h"
#import "NSString_extra.h"


#define BUCKET_PLIST_SALT "BucketPL"


@interface StringArrayPair : NSObject {
    NSString *left;
    NSArray *right;
}
- (id)initWithLeft:(NSString *)theLeft right:(NSArray *)theRight;
- (NSString *)left;
- (NSArray *)right;
@end

@implementation StringArrayPair
- (id)initWithLeft:(NSString *)theLeft right:(NSArray *)theRight {
    if (self = [super init]) {
        left = [theLeft retain];
        right = [theRight retain];
    }
    return self;
}
- (void)dealloc {
    [left release];
    [right release];
    [super dealloc];
}

- (NSString *)left {
    return left;
}
- (NSArray *)right {
    return right;
}
@end



@implementation Bucket
+ (NSArray *)bucketsWithTarget:(Target *)theTarget
                  computerUUID:(NSString *)theComputerUUID
            encryptionPassword:(NSString *)theEncryptionPassword
      targetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD
                         error:(NSError **)error {
    return [Bucket bucketsWithTarget:theTarget
                        computerUUID:theComputerUUID
                  encryptionPassword:(NSString *)theEncryptionPassword
            targetConnectionDelegate:theTCD
                    activityListener:nil
                               error:error];
}
+ (NSArray *)bucketsWithTarget:(Target *)theTarget
                  computerUUID:(NSString *)theComputerUUID
            encryptionPassword:(NSString *)theEncryptionPassword
      targetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD
              activityListener:(id <BucketActivityListener>)theActivityListener
                         error:(NSError **)error {
    HSLogDebug(@"bucketsWithTarget: theTarget=%@ endpoint=%@ path=%@", theTarget, [theTarget endpoint], [[theTarget endpoint] path]);
    
    TargetConnection *targetConnection = [theTarget newConnection:error];
    if (targetConnection == nil) {
        return nil;
    }
    NSMutableArray *ret = [NSMutableArray array];
    do {
        [theActivityListener bucketActivity:@"Loading folder list..."];
        NSArray *bucketUUIDs = [targetConnection bucketUUIDsForComputerUUID:theComputerUUID deleted:NO delegate:theTCD error:error];
        if (bucketUUIDs == nil) {
            if (error != NULL) {
                HSLogDebug(@"failed to load bucketUUIDs for target %@ computer %@: %@", theTarget, theComputerUUID, *error);
            }
            ret = nil;
            break;
        }
        for (NSUInteger i = 0; i < [bucketUUIDs count]; i++) {
            [theActivityListener bucketActivity:[NSString stringWithFormat:@"Loading folder %ld of %ld", i+1, [bucketUUIDs count]]];
            
            NSString *bucketUUID = [bucketUUIDs objectAtIndex:i];
            NSError *myError = nil;
            Bucket *bucket = [Bucket bucketWithTarget:theTarget
                                     targetConnection:targetConnection
                                         computerUUID:theComputerUUID
                                   encryptionPassword:theEncryptionPassword
                                           bucketUUID:bucketUUID
                             targetConnectionDelegate:theTCD
                                                error:&myError];
            if (bucket == nil) {
                HSLogError(@"failed to load bucket plist for %@/%@: %@", theComputerUUID, bucketUUID, myError);
                if ([myError code] != ERROR_INVALID_PLIST_XML) {
                    SETERRORFROMMYERROR;
                    ret = nil;
                    break;
                }
            } else {
                [ret addObject:bucket];
            }
        }
        NSSortDescriptor *descriptor = [[[NSSortDescriptor alloc] initWithKey:@"bucketName" ascending:YES selector:@selector(caseInsensitiveCompare:)] autorelease];
        [ret sortUsingDescriptors:[NSArray arrayWithObject:descriptor]];
    } while(0);
    [targetConnection release];
    HSLogDebug(@"returning %ld buckets for computer %@", [ret count], theComputerUUID);
    return ret;
}
+ (NSArray *)bucketUUIDsWithTarget:(Target *)theTarget
                      computerUUID:(NSString *)theComputerUUID
          targetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD
                             error:(NSError **)error {
    TargetConnection *targetConnection = [theTarget newConnection:error];
    if (targetConnection == nil) {
        return nil;
    }
    NSArray *ret = [targetConnection bucketUUIDsForComputerUUID:theComputerUUID deleted:NO delegate:theTCD error:error];
    [targetConnection release];
    return ret;
}


+ (NSString *)errorDomain {
    return @"BucketErrorDomain";
}

- (id)initWithTarget:(Target *)theTarget
          bucketUUID:(NSString *)theBucketUUID
          bucketName:(NSString *)theBucketName
        computerUUID:(NSString *)theComputerUUID
           localPath:(NSString *)theLocalPath
     localMountPoint:(NSString *)theLocalMountPoint
         storageType:(int)theStorageType {
    if (self = [super init]) {
        target = [theTarget retain];
        bucketUUID = [theBucketUUID retain];
        bucketName = [theBucketName retain];
        computerUUID = [theComputerUUID retain];
        localPath = [theLocalPath retain];
        localMountPoint = [theLocalMountPoint retain];
        storageType = theStorageType;
        ignoredRelativePaths = [[NSMutableArray alloc] init];
        excludeSet = [[BucketExcludeSet alloc] init];
        excludeItemsWithTimeMachineExcludeMetadataFlag = NO; // Default to false because things might get unexpectedly skipped, e.g. VMWare VMs
    }
    return self;
}
- (id)initWithBufferedInputStream:(BufferedInputStream *)theBIS error:(NSError **)error {
    Target *theTarget = [[[Target alloc] initWithBufferedInputStream:theBIS error:error] autorelease];
    if (theTarget == nil) {
        [self release];
        return nil;
    }
    NSData *xmlData = nil;
    if (![DataIO read:&xmlData from:theBIS error:error]) {
        [self release];
        return nil;
    }
    if (xmlData == nil) {
        SETNSERROR([Bucket errorDomain], -1, @"nil xmlData!");
        [self release];
        return nil;
    }
    DictNode *plist = [DictNode dictNodeWithXMLData:xmlData error:error];
    if (plist == nil) {
        [self release];
        return nil;
    }
    return [self initWithTarget:theTarget plist:plist];
}
- (void)dealloc {
    [target release];
    [bucketUUID release];
    [bucketName release];
    [computerUUID release];
    [localPath release];
    [localMountPoint release];
    [ignoredRelativePaths release];
    [excludeSet release];
    [vaultName release];
    [vaultCreatedDate release];
    [plistDeletedDate release];
    [super dealloc];
}

- (Target *)target {
    return target;
}
- (NSString *)computerUUID {
    return computerUUID;
}
- (NSString *)bucketUUID {
    return bucketUUID;
}
- (NSString *)bucketName {
    return bucketName;
}
- (NSString *)localPath {
    return localPath;
}
- (NSString *)localMountPoint {
    return localMountPoint;
}
- (StorageType)storageType {
    return storageType;
}
- (BucketExcludeSet *)bucketExcludeSet {
    return excludeSet;
}
- (NSString *)vaultName {
    return vaultName;
}
- (NSDate *)vaultCreatedDate {
    return vaultCreatedDate;
}
- (NSDate *)plistDeletedDate {
    return plistDeletedDate;
}
- (BOOL)skipDuringBackup {
    return skipDuringBackup;
}
- (BOOL)excludeItemsWithTimeMachineExcludeMetadataFlag {
    return excludeItemsWithTimeMachineExcludeMetadataFlag;
}
- (BucketPathState)stateForPath:(NSString *)thePath ignoreExcludes:(BOOL)ignoreExcludes {
    if ([ignoredRelativePaths containsObject:@""]) {
        return BucketPathOffState;
    }
    
    NSInteger ret = BucketPathOnState;
    if ([thePath length] <= [localPath length]) {
        HSLogDebug(@"path %@ isn't longer than localPath %@", thePath, localPath);
    } else {
        NSString *relativePath = [thePath substringFromIndex:[localPath length]];
        for (NSString *ignoredRelativePath in ignoredRelativePaths) {
            if ([relativePath isEqualToString:ignoredRelativePath]
                || ([relativePath hasPrefix:ignoredRelativePath] && ([relativePath length] > [ignoredRelativePath length]) && ([relativePath characterAtIndex:[ignoredRelativePath length]] == '/'))
                ) {
                ret = BucketPathOffState;
                break;
            } else if (([ignoredRelativePath hasPrefix:relativePath] || [relativePath length] == 0)
                       && ([ignoredRelativePath length] > [relativePath length])
                       && ([relativePath isEqualToString:@""] || [relativePath isEqualToString:@"/"] || [ignoredRelativePath characterAtIndex:[relativePath length]] == '/')) {
                ret = BucketPathMixedState;
                break;
            }
        }
    }
    if (!ignoreExcludes && [excludeSet matchesFullPath:thePath filename:[thePath lastPathComponent]]) {
        return BucketPathOffState;
    }
    return ret;
}
- (NSSet *)ignoredRelativePaths {
    return [NSSet setWithArray:ignoredRelativePaths];
}
- (BOOL)skipIfNotMounted {
    return skipIfNotMounted;
}
- (NSData *)toXMLData {
    DictNode *plist = [[[DictNode alloc] init] autorelease];
    [plist putString:[[target endpoint] description] forKey:@"Endpoint"];
    [plist putString:bucketUUID forKey:@"BucketUUID"];
    [plist putString:bucketName forKey:@"BucketName"];
    [plist putString:computerUUID forKey:@"ComputerUUID"];
    [plist putString:localPath forKey:@"LocalPath"];
    [plist putString:localMountPoint forKey:@"LocalMountPoint"];
    [plist putInt:storageType forKey:@"StorageType"];
    if (vaultName != nil) {
        [plist putString:vaultName forKey:@"VaultName"];
    }
    if (vaultCreatedDate != nil) {
        [plist putDouble:[vaultCreatedDate timeIntervalSinceReferenceDate] forKey:@"VaultCreatedTime"];
    }
    if (plistDeletedDate != nil) {
        [plist putDouble:[plistDeletedDate timeIntervalSinceReferenceDate] forKey:@"PlistDeletedTime"];
    }
    [plist putBoolean:skipDuringBackup forKey:@"SkipDuringBackup"];
    [plist putBoolean:excludeItemsWithTimeMachineExcludeMetadataFlag forKey:@"ExcludeItemsWithTimeMachineExcludeMetadataFlag"];
    ArrayNode *ignoredRelativePathsNode = [[[ArrayNode alloc] init] autorelease];
    [plist put:ignoredRelativePathsNode forKey:@"IgnoredRelativePaths"];
    NSArray *sortedRelativePaths = [ignoredRelativePaths sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
    for (NSString *ignoredRelativePath in sortedRelativePaths) {
        [ignoredRelativePathsNode add:[[[StringNode alloc] initWithString:ignoredRelativePath] autorelease]];
    }
    [plist put:[excludeSet toPlist] forKey:@"Excludes"];
    [plist putBoolean:skipIfNotMounted forKey:@"SkipIfNotMounted"];
    return [plist XMLData];
}
- (BOOL)writeTo:(BufferedOutputStream *)theBOS error:(NSError **)error {
    NSData *data = [self toXMLData];
    return [target writeTo:theBOS error:error] && [DataIO write:data to:theBOS error:error];
}
- (void)writeTo:(NSMutableData *)data {
    [target writeTo:data];
    [DataIO write:[self toXMLData] to:data];
}

#pragma mark NSCopying
- (id)copyWithZone:(NSZone *)zone {
    BucketExcludeSet *excludeSetCopy = [excludeSet copyWithZone:zone];
    NSMutableArray *ignoredRelativePathsCopy = [[NSMutableArray alloc] initWithArray:ignoredRelativePaths copyItems:YES];
    Bucket *ret = [[Bucket alloc] initWithTarget:target
                                      bucketUUID:bucketUUID
                                      bucketName:bucketName
                                    computerUUID:computerUUID
                                       localPath:localPath
                                 localMountPoint:localMountPoint
                                     storageType:storageType
                            ignoredRelativePaths:ignoredRelativePathsCopy
                                      excludeSet:excludeSetCopy
                                       vaultName:vaultName
                                vaultCreatedDate:vaultCreatedDate
                                plistDeletedDate:plistDeletedDate
                                skipDuringBackup:skipDuringBackup
  excludeItemsWithTimeMachineExcludeMetadataFlag:excludeItemsWithTimeMachineExcludeMetadataFlag
                                skipIfNotMounted:skipIfNotMounted];
    [excludeSetCopy release];
    [ignoredRelativePathsCopy release];
    return ret;
}

#pragma mark NSObject
- (NSString *)description {
    NSUInteger ignoredCount = [ignoredRelativePaths count];
    return [NSString stringWithFormat:@"<Bucket %@: %@ (%lu ignored path%@)>", bucketUUID, localPath, (unsigned long)ignoredCount, (ignoredCount == 1 ? @"" : @"s")];
}


#pragma mark internal
+ (Bucket *)bucketWithTarget:(Target *)theTarget
            targetConnection:(TargetConnection *)theTargetConnection
                computerUUID:(NSString *)theComputerUUID
          encryptionPassword:(NSString *)theEncryptionPassword
                  bucketUUID:(NSString *)theBucketUUID
    targetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD
                       error:(NSError **)error {
    ObjectEncryptor *encryptor = [[[ObjectEncryptor alloc] initWithTarget:theTarget
                                                             computerUUID:theComputerUUID
                                                       encryptionPassword:theEncryptionPassword
                                                             customV1Salt:[NSData dataWithBytes:BUCKET_PLIST_SALT length:strlen(BUCKET_PLIST_SALT)]
                                                 targetConnectionDelegate:nil
                                                                    error:error] autorelease];
    if (encryptor == nil) {
        return nil;
    }

    BOOL encrypted = NO;
    NSData *data = [theTargetConnection bucketPlistDataForComputerUUID:theComputerUUID bucketUUID:theBucketUUID deleted:NO delegate:theTCD error:error];
    if (data == nil) {
        return nil;
    }
    unsigned long length = 9;
    if ([data length] < length) {
        length = [data length];
    }
    if (length >= 9 && !strncmp([data bytes], "encrypted", length)) {
        encrypted = YES;
        NSData *encryptedData = [data subdataWithRange:NSMakeRange(9, [data length] - 9)];
        data = [encryptor decryptedDataForObject:encryptedData error:error];
        if (data == nil) {
            return nil;
        }
    }
    NSError *myError = nil;
    DictNode *plist = [DictNode dictNodeWithXMLData:data error:&myError];
    if (plist == nil) {
        HSLogDebug(@"error parsing XML data into DictNode: %@", myError);
        NSString *str = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
        HSLogDebug(@"invalid XML: %@", str);
        SETNSERROR(@"BucketErrorDomain", ERROR_INVALID_PLIST_XML, @"%@ %@ not valid XML", theComputerUUID, theBucketUUID);
        return nil;
    }
    Bucket *bucket = [[[Bucket alloc] initWithTarget:theTarget plist:plist] autorelease];
    return bucket;
}

- (id)initWithTarget:(Target *)theTarget plist:(DictNode *)thePlist {
    if (self = [super init]) {
        target = [theTarget retain];
        bucketUUID = [[[thePlist stringNodeForKey:@"BucketUUID"] stringValue] retain];
        bucketName = [[[thePlist stringNodeForKey:@"BucketName"] stringValue] retain];
        computerUUID = [[[thePlist stringNodeForKey:@"ComputerUUID"] stringValue] retain];
        localPath = [[[thePlist stringNodeForKey:@"LocalPath"] stringValue] retain];
        localMountPoint = [[[thePlist stringNodeForKey:@"LocalMountPoint"] stringValue] retain];
        storageType = StorageTypeS3;
        if ([thePlist containsKey:@"StorageType"]) {
            storageType = [[thePlist integerNodeForKey:@"StorageType"] intValue];
        }
        vaultName = [[[thePlist stringNodeForKey:@"VaultName"] stringValue] retain];
        if ([thePlist containsKey:@"VaultCreatedTime"]) {
            vaultCreatedDate = [[NSDate alloc] initWithTimeIntervalSinceReferenceDate:[[thePlist realNodeForKey:@"VaultCreatedTime"] doubleValue]];
        }
        if ([thePlist containsKey:@"PlistDeletedTime"]) {
            plistDeletedDate = [[NSDate alloc] initWithTimeIntervalSinceReferenceDate:[[thePlist realNodeForKey:@"PlistDeletedTime"] doubleValue]];
        }
        if ([thePlist containsKey:@"SkipDuringBackup"]){
            skipDuringBackup = [[thePlist booleanNodeForKey:@"SkipDuringBackup"] booleanValue];
        }
        if ([thePlist containsKey:@"ExcludeItemsWithTimeMachineExcludeMetadataFlag"]) {
            excludeItemsWithTimeMachineExcludeMetadataFlag = [[thePlist booleanNodeForKey:@"ExcludeItemsWithTimeMachineExcludeMetadataFlag"] booleanValue];
        }
        ignoredRelativePaths = [[NSMutableArray alloc] init];
        ArrayNode *ignoredPathsNode = [thePlist arrayNodeForKey:@"IgnoredRelativePaths"];
        for (NSUInteger index = 0; index < [ignoredPathsNode size]; index++) {
            [ignoredRelativePaths addObject:[[ignoredPathsNode stringNodeAtIndex:(int)index] stringValue]];
        }
        [self sortIgnoredRelativePaths];
        excludeSet = [[BucketExcludeSet alloc] init];
        [excludeSet loadFromPlist:[thePlist dictNodeForKey:@"Excludes"] localPath:localPath];
        
        if ([thePlist containsKey:@"SkipIfNotMounted"]) {
            skipIfNotMounted = [[thePlist booleanNodeForKey:@"SkipIfNotMounted"] booleanValue];
        }
    }
    return self;
}

- (void)sortIgnoredRelativePaths {
    // Filter out duplicates.
    NSSet *set = [NSSet setWithArray:ignoredRelativePaths];
    [ignoredRelativePaths setArray:[set allObjects]];
    [ignoredRelativePaths sortUsingSelector:@selector(compareByLength:)];
}



- (id)initWithTarget:(Target *)theTarget
          bucketUUID:(NSString *)theBucketUUID
          bucketName:(NSString *)theBucketName
        computerUUID:(NSString *)theComputerUUID
           localPath:(NSString *)theLocalPath
     localMountPoint:(NSString *)theLocalMountPoint
         storageType:(int)theStorageType
ignoredRelativePaths:(NSMutableArray *)theIgnoredRelativePaths
          excludeSet:(BucketExcludeSet *)theExcludeSet
           vaultName:(NSString *)theVaultName
    vaultCreatedDate:(NSDate *)theVaultCreatedDate
    plistDeletedDate:(NSDate *)thePlistDeletedDate
    skipDuringBackup:(BOOL)theSkipDuringBackup
excludeItemsWithTimeMachineExcludeMetadataFlag:(BOOL)theExcludeItemsWithTimeMachineExcludeMetadataFlag
    skipIfNotMounted:(BOOL)theSkipIfNotMounted {
    if (self = [super init]) {
        target = [theTarget retain];
        bucketUUID = [theBucketUUID retain];
        bucketName = [theBucketName retain];
        computerUUID = [theComputerUUID retain];
        localPath = [theLocalPath retain];
        localMountPoint = [theLocalMountPoint retain];
        storageType = theStorageType;
        ignoredRelativePaths = [theIgnoredRelativePaths retain];
        excludeSet = [theExcludeSet retain];
        vaultName = [theVaultName retain];
        vaultCreatedDate = [theVaultCreatedDate retain];
        plistDeletedDate = [thePlistDeletedDate retain];
        skipDuringBackup = theSkipDuringBackup;
        excludeItemsWithTimeMachineExcludeMetadataFlag = theExcludeItemsWithTimeMachineExcludeMetadataFlag;
        skipIfNotMounted = theSkipIfNotMounted;
    }
    return self;
}
@end
