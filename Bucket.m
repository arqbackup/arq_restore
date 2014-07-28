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


#import "Bucket.h"
#import "DictNode.h"
#import "ArrayNode.h"
#import "StringNode.h"
#import "NSString_slashed.h"
#import "BucketExcludeSet.h"
#import "S3AuthorizationProvider.h"
#import "S3Service.h"
#import "UserLibrary_Arq.h"
#import "S3Service.h"
#import "StorageType.h"
#import "GlacierService.h"
#import "AWSRegion.h"
#import "RegexKitLite.h"
#import "AWSRegion.h"
#import "CryptoKey.h"
#import "Target.h"
#import "TargetConnection.h"
#import "GlacierAuthorizationProvider.h"
#import "GlacierService.h"
#import "ArqSalt.h"
#import "DataIO.h"
#import "StringIO.h"


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
    id <TargetConnection> targetConnection = [theTarget newConnection];
    NSMutableArray *ret = [NSMutableArray array];
    do {
        NSArray *bucketUUIDs = [targetConnection bucketUUIDsForComputerUUID:theComputerUUID deleted:NO delegate:theTCD error:error];
        if (bucketUUIDs == nil) {
            if (error != NULL) {
                HSLogDebug(@"failed to load bucketUUIDs for target %@ computer %@: %@", theTarget, theComputerUUID, *error);
            }
            ret = nil;
            break;
        }
        for (NSString *bucketUUID in bucketUUIDs) {
            NSError *myError = nil;
            Bucket *bucket = [Bucket bucketWithTarget:theTarget targetConnection:targetConnection computerUUID:theComputerUUID bucketUUID:bucketUUID encryptionPassword:theEncryptionPassword error:&myError];
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
    return ret;
}
+ (NSArray *)bucketUUIDsWithTarget:(Target *)theTarget
                      computerUUID:(NSString *)theComputerUUID
                encryptionPassword:(NSString *)theEncryptionPassword
          targetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD
                             error:(NSError **)error {
    id <TargetConnection> targetConnection = [[theTarget newConnection] autorelease];
    return [targetConnection bucketUUIDsForComputerUUID:theComputerUUID deleted:NO delegate:theTCD error:error];
}
+ (NSArray *)deletedBucketsWithTarget:(Target *)theTarget
                         computerUUID:(NSString *)theComputerUUID
                   encryptionPassword:(NSString *)theEncryptionPassword
             targetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD
                                error:(NSError **)error {
    HSLogDebug(@"deletedBucketsWithTarget: theTarget=%@ endpoint=%@ path=%@", theTarget, [theTarget endpoint], [[theTarget endpoint] path]);
    
    NSData *salt = [NSData dataWithBytes:BUCKET_PLIST_SALT length:8];
    CryptoKey *cryptoKey = [[[CryptoKey alloc] initWithPassword:theEncryptionPassword salt:salt error:error] autorelease];
    if (cryptoKey == nil) {
        return nil;
    }
    
    NSMutableArray *ret = [NSMutableArray array];
    id <TargetConnection> targetConnection = [[theTarget newConnection] autorelease];
    NSArray *deletedBucketUUIDs = [targetConnection bucketUUIDsForComputerUUID:theComputerUUID deleted:YES delegate:theTCD error:error];
    if (deletedBucketUUIDs == nil) {
        return nil;
    }
    for (NSString *bucketUUID in deletedBucketUUIDs) {
        NSData *data = [targetConnection bucketPlistDataForComputerUUID:theComputerUUID bucketUUID:bucketUUID deleted:YES delegate:theTCD error:error];
        if (data == nil) {
            return nil;
        }
        if (!strncmp([data bytes], "encrypted", 9)) {
            NSData *encryptedData = [data subdataWithRange:NSMakeRange(9, [data length] - 9)];
            data = [cryptoKey decrypt:encryptedData error:error];
            if (data == nil) {
                return nil;
            }
        }
        NSError *myError = nil;
        DictNode *plist = [DictNode dictNodeWithXMLData:data error:&myError];
        if (plist == nil) {
            SETNSERROR(@"BucketErrorDomain", -1, @"error parsing bucket plist %@ %@: %@", theComputerUUID, bucketUUID, [myError localizedDescription]);
            return nil;
        }
        Bucket *bucket = [[[Bucket alloc] initWithTarget:theTarget plist:plist] autorelease];
        [ret addObject:bucket];
    }
    NSSortDescriptor *descriptor = [[[NSSortDescriptor alloc] initWithKey:@"bucketName" ascending:YES selector:@selector(caseInsensitiveCompare:)] autorelease];
    [ret sortUsingDescriptors:[NSArray arrayWithObject:descriptor]];
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
        stringArrayPairs = [[NSMutableArray alloc] init];
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
    [stringArrayPairs release];
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
- (BucketPathState)stateForPath:(NSString *)thePath ignoreExcludes:(BOOL)ignoreExcludes {
    if ([ignoredRelativePaths containsObject:@""]) {
        return BucketPathOffState;
    }
    
    NSInteger ret = BucketPathOnState;
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
    if (!ignoreExcludes && [excludeSet matchesFullPath:thePath filename:[thePath lastPathComponent]]) {
        return BucketPathOffState;
    }
    return ret;
}
- (void)setIgnoredRelativePaths:(NSSet *)theSet {
    [ignoredRelativePaths setArray:[theSet allObjects]];
}
- (NSSet *)ignoredRelativePaths {
    return [NSSet setWithArray:ignoredRelativePaths];
}
- (void)enteredPath:(NSString *)thePath {
    NSMutableArray *relativePathsToSkip = [NSMutableArray array];
    if (![thePath isEqualToString:localPath]) {
        NSString *relativePath = [thePath substringFromIndex:[localPath length]];
        for (NSString *ignored in ignoredRelativePaths) {
            BOOL applicable = NO;
            if ([ignored hasPrefix:relativePath]) {
                if ([ignored isEqualToString:relativePath] || ([ignored characterAtIndex:[relativePath length]] == '/')) {
                    applicable = YES;
                }
            }
            if (!applicable) {
                [relativePathsToSkip addObject:ignored];
            }
        }
    }
    StringArrayPair *sap = [[StringArrayPair alloc] initWithLeft:thePath right:relativePathsToSkip];
    [stringArrayPairs addObject:sap];
    [sap release];
    [ignoredRelativePaths removeObjectsInArray:relativePathsToSkip];
}
- (void)leftPath:(NSString *)thePath {
    StringArrayPair *sap = [stringArrayPairs lastObject];
    NSAssert([[sap left] isEqualToString:thePath], @"must leave last path on the stack!");
    [ignoredRelativePaths addObjectsFromArray:[sap right]];
    [stringArrayPairs removeLastObject];
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
    [plist putString:vaultName forKey:@"VaultName"];
    if (vaultCreatedDate != nil) {
        [plist putDouble:[vaultCreatedDate timeIntervalSinceReferenceDate] forKey:@"VaultCreatedTime"];
    }
    if (plistDeletedDate != nil) {
        [plist putDouble:[plistDeletedDate timeIntervalSinceReferenceDate] forKey:@"PlistDeletedTime"];
    }
    ArrayNode *ignoredRelativePathsNode = [[[ArrayNode alloc] init] autorelease];
    [plist put:ignoredRelativePathsNode forKey:@"IgnoredRelativePaths"];
    NSArray *sortedRelativePaths = [ignoredRelativePaths sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
    for (NSString *ignoredRelativePath in sortedRelativePaths) {
        [ignoredRelativePathsNode add:[[[StringNode alloc] initWithString:ignoredRelativePath] autorelease]];
    }
    [plist put:[excludeSet toPlist] forKey:@"Excludes"];
    return [plist XMLData];
}


#pragma mark NSCopying
- (id)copyWithZone:(NSZone *)zone {
    BucketExcludeSet *excludeSetCopy = [excludeSet copyWithZone:zone];
    NSMutableArray *stringArrayPairsCopy = [stringArrayPairs copyWithZone:zone];
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
                                stringArrayPairs:stringArrayPairsCopy
                                       vaultName:vaultName
                                vaultCreatedDate:vaultCreatedDate
                                plistDeletedDate:plistDeletedDate];
    [excludeSetCopy release];
    [stringArrayPairsCopy release];
    [ignoredRelativePathsCopy release];
    return ret;
}

#pragma mark NSObject
- (NSString *)description {
    return [NSString stringWithFormat:@"<Bucket %@: %@ (%lu ignored paths)>", bucketUUID, localPath, (unsigned long)[ignoredRelativePaths count]];
}


#pragma mark internal
+ (Bucket *)bucketWithTarget:(Target *)theTarget
            targetConnection:(id <TargetConnection>)theTargetConnection
                computerUUID:(NSString *)theComputerUUID
                  bucketUUID:(NSString *)theBucketUUID
          encryptionPassword:(NSString *)theEncryptionPassword
                       error:(NSError **)error {
    NSData *salt = [NSData dataWithBytes:BUCKET_PLIST_SALT length:8];
    CryptoKey *cryptoKey = [[[CryptoKey alloc] initWithPassword:theEncryptionPassword salt:salt error:error] autorelease];
    if (cryptoKey == nil) {
        return nil;
    }
    
    BOOL encrypted = NO;
    NSData *data = [theTargetConnection bucketPlistDataForComputerUUID:theComputerUUID bucketUUID:theBucketUUID deleted:NO delegate:nil error:error];
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
        data = [cryptoKey decrypt:encryptedData error:error];
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
        ignoredRelativePaths = [[NSMutableArray alloc] init];
        ArrayNode *ignoredPathsNode = [thePlist arrayNodeForKey:@"IgnoredRelativePaths"];
        for (NSUInteger index = 0; index < [ignoredPathsNode size]; index++) {
            [ignoredRelativePaths addObject:[[ignoredPathsNode stringNodeAtIndex:(int)index] stringValue]];
        }
        [self sortIgnoredRelativePaths];
        excludeSet = [[BucketExcludeSet alloc] init];
        [excludeSet loadFromPlist:[thePlist dictNodeForKey:@"Excludes"] localPath:localPath];
        stringArrayPairs = [[NSMutableArray alloc] init];
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
    stringArrayPairs:(NSMutableArray *)theStringArrayPairs
           vaultName:(NSString *)theVaultName
    vaultCreatedDate:(NSDate *)theVaultCreatedDate
    plistDeletedDate:(NSDate *)thePlistDeletedDate {
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
        stringArrayPairs = [theStringArrayPairs retain];
        vaultName = [theVaultName retain];
        vaultCreatedDate = [theVaultCreatedDate retain];
        plistDeletedDate = [thePlistDeletedDate retain];
    }
    return self;
}
@end
