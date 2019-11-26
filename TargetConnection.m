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



#import "TargetConnection.h"
#import "Target.h"
#import "RegexKitLite.h"
#import "S3ObjectMetadata.h"
#import "Item.h"
#import "RemoteFS.h"
#import "S3AuthorizationProviderFactory.h"
#import "S3Service.h"
#import "LocalItemFS.h"
#import "UserLibrary_Arq.h"
#import "AWSRegion.h"
#import "MD5Hash.h"
#import "IntegerIO.h"
#import "DataInputStream.h"
#import "BufferedInputStream.h"


@implementation TargetConnection
- (id)initWithTarget:(Target *)theTarget {
    if (self = [super init]) {
        target = [theTarget retain];
        if ([[[theTarget endpoint] path] isEqualToString:@"/"]) {
            pathPrefix = [@"" retain];
        } else {
            pathPrefix = [[[theTarget endpoint] path] retain];
        }
        
        remoteFSByThreadId = [[NSMutableDictionary alloc] init];
        lock = [[NSLock alloc] init];
        [lock setName:@"TargetConnection lock"];
    }
    return self;
}

- (void)dealloc {
    [target release];
    [pathPrefix release];
    [remoteFSByThreadId release];
    [lock release];
    [super dealloc];
}

- (BOOL)updateFingerprintWithTargetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD error:(NSError **)error {
    RemoteFS *remoteFS = [self remoteFS:error];
    if (remoteFS == nil) {
        return NO;
    }
    return [remoteFS updateFingerprintWithTargetConnectionDelegate:theTCD error:error];
}

- (Item *)itemAtPath:(NSString *)thePath targetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD error:(NSError **)error {
    return [[self remoteFS:error] itemAtPath:thePath targetConnectionDelegate:theTCD error:error];
}
- (NSDictionary *)itemsByNameAtPath:(NSString *)thePath targetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD error:(NSError **)error {
    return [[self remoteFS:error] itemsByNameInDirectory:thePath targetConnectionDelegate:theTCD error:error];
}

- (NSArray *)computerUUIDsWithDelegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    RemoteFS *remoteFS = [self remoteFS:error];
    if (remoteFS == nil) {
        return nil;
    }
    
    // Don't clear the cache because it means you'd have to query for the entire list of objects if you try to restore a file.
    // Instead, tell the user to use the Clear Cache button.
//    if (![remoteFS clearCacheForPath:[[target endpoint] path] error:error]) {
//        return nil;
//    }
    NSDictionary *itemsByName = [remoteFS itemsByNameInDirectory:[[target endpoint] path] useCachedData:NO targetConnectionDelegate:theDelegate error:error];
    if (itemsByName == nil) {
        return nil;
    }
    
    HSLogDebug(@"found %ld items at %@: %@", [itemsByName count], [target endpoint], [itemsByName allKeys]);
    
    NSMutableArray *ret = [NSMutableArray array];
    for (Item *item in [itemsByName allValues]) {
        if ([item.name rangeOfRegex:@"^(\\S{8}-\\S{4}-\\S{4}-\\S{4}-\\S{12})$"].location != NSNotFound) {
            [ret addObject:item.name];
        } else {
            HSLogDebug(@"%@ is not a UUID; skipping", item.name);
        }
    }
    HSLogDebug(@"found %ld UUIDs at %@: %@", [ret count], [target endpoint], ret);
    return ret;
}

- (NSArray *)bucketUUIDsForComputerUUID:(NSString *)theComputerUUID deleted:(BOOL)deleted delegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    RemoteFS *remoteFS = [self remoteFS:error];
    if (remoteFS == nil) {
        return nil;
    }
    NSString *subdir = deleted ? @"deletedbuckets" : @"buckets";
    NSString *bucketsDir = [NSString stringWithFormat:@"%@/%@/%@", pathPrefix, theComputerUUID, subdir];
    NSDictionary *itemsByName = [remoteFS itemsByNameInDirectory:bucketsDir useCachedData:NO targetConnectionDelegate:theDelegate error:error];
    if (itemsByName == nil) {
        return nil;
    }
    
    NSMutableArray *ret = [NSMutableArray array];
    for (Item *item in [itemsByName allValues]) {
        if ([item.name rangeOfRegex:@"^(\\S{8}-\\S{4}-\\S{4}-\\S{4}-\\S{12})$"].location != NSNotFound) {
            [ret addObject:item.name];
        }
    }
    return ret;
}

- (NSData *)bucketPlistDataForComputerUUID:(NSString *)theComputerUUID bucketUUID:(NSString *)theBucketUUID deleted:(BOOL)deleted delegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    NSString *subdir = deleted ? @"deletedbuckets" : @"buckets";
    NSString *path = [NSString stringWithFormat:@"%@/%@/%@/%@", pathPrefix, theComputerUUID, subdir, theBucketUUID];
    return [[self remoteFS:error] contentsOfFileAtPath:path dataTransferDelegate:nil targetConnectionDelegate:theDelegate error:error];
}
- (BOOL)saveBucketPlistData:(NSData *)theData forComputerUUID:(NSString *)theComputerUUID bucketUUID:(NSString *)theBucketUUID deleted:(BOOL)deleted delegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    RemoteFS *remoteFS = [self remoteFS:error];
    if (remoteFS == nil) {
        return NO;
    }
    NSString *subdir = deleted ? @"deletedbuckets" : @"buckets";
    NSString *path = [NSString stringWithFormat:@"%@/%@/%@/%@", pathPrefix, theComputerUUID, subdir, theBucketUUID];
    NSError *myError = nil;
    NSData *existingPlist = [remoteFS contentsOfFileAtPath:path dataTransferDelegate:nil targetConnectionDelegate:nil error:&myError];
    if (existingPlist != nil) {
        // Copy existing file to /<prefix>/<computerUUID>/bucketdata/<uuid>/plist_history/<timeinterval>/<bucketUUID>
        NSString *backupPath = [NSString stringWithFormat:@"%@/%@/bucketdata/%@/plist_history/%0.0f/%@", pathPrefix, theComputerUUID, theBucketUUID, [NSDate timeIntervalSinceReferenceDate], theBucketUUID];
        if (![remoteFS createFileAtomicallyWithData:existingPlist atPath:backupPath dataTransferDelegate:nil targetConnectionDelegate:nil error:&myError]) {
            HSLogError(@"failed to save previous plist to %@: %@", backupPath, myError);
        }
    }
    Item *item = [remoteFS createFileAtomicallyWithData:theData atPath:path dataTransferDelegate:nil targetConnectionDelegate:theDelegate error:error];
    return item != nil;
}
- (BOOL)deleteBucketPlistDataForComputerUUID:(NSString *)theComputerUUID bucketUUID:(NSString *)theBucketUUID deleted:(BOOL)deleted delegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    RemoteFS *remoteFS = [self remoteFS:error];
    if (remoteFS == nil) {
        return NO;
    }
    NSString *subdir = deleted ? @"deletedbuckets" : @"buckets";
    NSString *path = [NSString stringWithFormat:@"%@/%@/%@/%@", pathPrefix, theComputerUUID, subdir, theBucketUUID];
    return [remoteFS removeItemAtPath:path targetConnectionDelegate:theDelegate error:error];
}

- (NSData *)computerInfoForComputerUUID:(NSString *)theComputerUUID delegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    NSString *path = [NSString stringWithFormat:@"%@/%@/computerinfo", pathPrefix, theComputerUUID];
    return [[self remoteFS:error] contentsOfFileAtPath:path dataTransferDelegate:nil targetConnectionDelegate:theDelegate error:error];
}
- (BOOL)saveComputerInfo:(NSData *)theData forComputerUUID:(NSString *)theComputerUUID delegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    NSString *path = [NSString stringWithFormat:@"%@/%@/computerinfo", pathPrefix, theComputerUUID];
    Item *item = [[self remoteFS:error] createFileAtomicallyWithData:theData atPath:path dataTransferDelegate:nil targetConnectionDelegate:theDelegate error:error];
    return item != nil;
}
- (BOOL)deleteObjectsForComputerUUID:(NSString *)theComputerUUID delegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    RemoteFS *remoteFS = [self remoteFS:error];
    if (remoteFS == nil) {
        return NO;
    }
    return [remoteFS removeItemAtPath:[NSString stringWithFormat:@"%@/%@", pathPrefix, theComputerUUID] targetConnectionDelegate:theDelegate error:error];
}
- (NSNumber *)fileExistsAtPath:(NSString *)thePath dataSize:(unsigned long long *)theDataSize delegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    NSError *myError = nil;
    Item *item = [self itemAtPath:thePath targetConnectionDelegate:theDelegate error:&myError];
    if (item == nil) {
        if ([myError code] != ERROR_NOT_FOUND) {
            SETERRORFROMMYERROR;
            return nil;
        }
        return [NSNumber numberWithBool:NO];
    }
    if (theDataSize != NULL) {
        if (!item.isDirectory) {
            *theDataSize = item.fileSize;
        }
    }
    return [NSNumber numberWithBool:YES];
}
- (NSData *)contentsOfFileAtPath:(NSString *)thePath delegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    return [self contentsOfRange:NSMakeRange(NSNotFound, 0) ofFileAtPath:thePath delegate:theDelegate error:error];
}
- (NSData *)contentsOfRange:(NSRange)theRange ofFileAtPath:(NSString *)thePath delegate:(id<TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    return [[self remoteFS:error] contentsOfRange:theRange ofFileAtPath:thePath dataTransferDelegate:nil targetConnectionDelegate:theDelegate error:error];
}
- (BOOL)writeData:(NSData *)theData toFileAtPath:(NSString *)thePath dataTransferDelegate:(id <DataTransferDelegate>)theDataTransferDelegate targetConnectionDelegate:(id <TargetConnectionDelegate>)theTargetConnectionDelegate error:(NSError **)error {
    RemoteFS *remoteFS = [self remoteFS:error];
    if (remoteFS == nil) {
        return NO;
    }
    Item *item = [remoteFS createFileAtomicallyWithData:theData atPath:thePath dataTransferDelegate:theDataTransferDelegate targetConnectionDelegate:theTargetConnectionDelegate error:error];
    return item != nil;
}
- (BOOL)removeItemAtPath:(NSString *)thePath delegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    RemoteFS *remoteFS = [self remoteFS:error];
    if (remoteFS == nil) {
        return NO;
    }
    return [remoteFS removeItemAtPath:thePath targetConnectionDelegate:theDelegate error:error];
}

- (NSString *)checksumOfFileAtPath:(NSString *)thePath delegate:(id <TargetConnectionDelegate>)theTCD error:(NSError **)error {
    RemoteFS *remoteFS = [self remoteFS:error];
    if (remoteFS == nil) {
        return nil;
    }
    Item *item = [remoteFS itemAtPath:thePath targetConnectionDelegate:theTCD error:error];
    if (item == nil) {
        return nil;
    }
    if (item.checksum != nil) {
        return item.checksum;
    }
    
    HSLogDebug(@"no checksum in Item; downloading %@ to calculate md5 hash", thePath);
    NSData *data = [self contentsOfFileAtPath:thePath delegate:theTCD error:error];
    if (data == nil) {
        return nil;
    }
    NSString *md5 = [MD5Hash hashData:data];
    return [@"md5:" stringByAppendingString:md5];
}

- (NSNumber *)aggregateSizeOfItemAtPath:(NSString *)thePath delegate:(id <TargetConnectionDelegate>)theTCD error:(NSError **)error {
    RemoteFS *remoteFS = [self remoteFS:error];
    if (remoteFS == nil) {
        return nil;
    }
    NSError *myError = nil;
    Item *item = [remoteFS itemAtPath:thePath targetConnectionDelegate:theTCD error:&myError];
    if (item == nil) {
        if ([myError code] != ERROR_NOT_FOUND) {
            SETERRORFROMMYERROR;
            return nil;
        }
        return [NSNumber numberWithLong:0];
    }
    
    return [self aggregateSizeOfItem:item atPath:thePath delegate:theTCD error:error];
}
- (NSNumber *)aggregateSizeOfItem:(Item *)theItem atPath:(NSString *)thePath delegate:(id<TargetConnectionDelegate>)theTCD error:(NSError **)error {
    unsigned long long total = 0;
    
    if (theItem.isDirectory) {
        NSNumber *childSize = [self aggregateSizeOfDirectoryAtPath:thePath delegate:theTCD error:error];
        if (childSize == nil) {
            return nil;
        }
        total += [childSize unsignedLongLongValue];
    } else {
        total = theItem.fileSize;
    }
    return [NSNumber numberWithUnsignedLongLong:total];
}
- (NSNumber *)aggregateSizeOfDirectoryAtPath:(NSString *)thePath delegate:(id <TargetConnectionDelegate>)theTCD error:(NSError **)error {
    RemoteFS *remoteFS = [self remoteFS:error];
    if (remoteFS == nil) {
        return nil;
    }
    NSDictionary *itemsByName = [remoteFS itemsByNameInDirectory:thePath targetConnectionDelegate:theTCD error:error];
    if (itemsByName == nil) {
        return nil;
    }
    unsigned long long total = 0;
    BOOL ret = YES;
    NSAutoreleasePool *pool = nil;
    for (Item *item in [itemsByName allValues]) {
        [pool drain];
        pool = [[NSAutoreleasePool alloc] init];
        if (theTCD != nil && ![theTCD targetConnectionShouldRetryOnTransientError:error]) {
            ret = NO;
            break;
        }
        if (item.isDirectory) {
            NSString *childPath = [thePath stringByAppendingPathComponent:item.name];
            NSNumber *size = [self aggregateSizeOfItemAtPath:childPath delegate:theTCD error:error];
            if (size == nil) {
                ret = NO;
                break;
            }
            total += [size unsignedLongLongValue];
        } else {
            total += item.fileSize;
        }
    }
    if (!ret && error != NULL) {
        [*error retain];
    }
    [pool drain];
    if (!ret && error != NULL) {
        [*error autorelease];
    }
    if (!ret) {
        return nil;
    }
    return [NSNumber numberWithUnsignedLongLong:total];
}

- (NSNumber *)isObjectRestoredAtPath:(NSString *)thePath delegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    return [[self remoteFS:error] isObjectRestoredAtPath:thePath targetConnectionDelegate:theDelegate error:error];
}
- (BOOL)restoreObjectAtPath:(NSString *)thePath forDays:(NSUInteger)theDays tier:(int)theGlacierRetrievalTier alreadyRestoredOrRestoring:(BOOL *)alreadyRestoredOrRestoring delegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    RemoteFS *remoteFS = [self remoteFS:error];
    if (remoteFS == nil) {
        return NO;
    }
    return [remoteFS restoreObjectAtPath:thePath forDays:theDays tier:theGlacierRetrievalTier alreadyRestoredOrRestoring:alreadyRestoredOrRestoring targetConnectionDelegate:theDelegate error:error];
}

- (NSData *)saltDataForComputerUUID:(NSString *)theComputerUUID delegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    NSString *s3Path = [NSString stringWithFormat:@"%@/%@/salt", pathPrefix, theComputerUUID];
    return [[self remoteFS:error] contentsOfFileAtPath:s3Path dataTransferDelegate:nil targetConnectionDelegate:theDelegate error:error];
}
- (BOOL)setSaltData:(NSData *)theData forComputerUUID:(NSString *)theComputerUUID delegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    RemoteFS *remoteFS = [self remoteFS:error];
    if (remoteFS == nil) {
        return NO;
    }
    NSString *s3Path = [NSString stringWithFormat:@"%@/%@/salt", pathPrefix, theComputerUUID];
    Item *item = [remoteFS createFileAtomicallyWithData:theData atPath:s3Path dataTransferDelegate:nil targetConnectionDelegate:theDelegate error:error];
    return item != nil;
}
- (BOOL)deleteSaltDataForComputerUUID:(NSString *)theComputerUUID delegate:(id<TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    RemoteFS *remoteFS = [self remoteFS:error];
    if (remoteFS == nil) {
        return NO;
    }
    NSString *s3Path = [NSString stringWithFormat:@"%@/%@/salt", pathPrefix, theComputerUUID];
    return [remoteFS removeItemAtPath:s3Path targetConnectionDelegate:theDelegate error:error];
}

- (NSData *)encryptionDataForComputerUUID:(NSString *)theComputerUUID encryptionVersion:(int)theEncryptionVersion delegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    NSString *s3Path = [NSString stringWithFormat:@"%@/%@/encryptionv%d.dat", pathPrefix, theComputerUUID, theEncryptionVersion];
    return [[self remoteFS:error] contentsOfFileAtPath:s3Path dataTransferDelegate:nil targetConnectionDelegate:theDelegate error:error];
}
- (BOOL)setEncryptionData:(NSData *)theData forComputerUUID:(NSString *)theComputerUUID encryptionVersion:(int)theEncryptionVersion delegate:(id<TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    RemoteFS *remoteFS = [self remoteFS:error];
    if (remoteFS == nil) {
        return NO;
    }
    NSString *s3Path = [NSString stringWithFormat:@"%@/%@/encryptionv%d.dat", pathPrefix, theComputerUUID, theEncryptionVersion];
    Item *item = [remoteFS createFileAtomicallyWithData:theData atPath:s3Path dataTransferDelegate:nil targetConnectionDelegate:theDelegate error:error];
    return item != nil;
}

- (NSDictionary *)pathsBySHA1WithIsGlacier:(BOOL)theIsGlacier computerUUID:(NSString *)theComputerUUID delegate:(id<TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    RemoteFS *remoteFS = [self remoteFS:error];
    if (remoteFS == nil) {
        return nil;
    }
    NSString *objectsDir = [NSString stringWithFormat:@"%@/%@%@/objects", [[target endpoint] path], (theIsGlacier ? @"glacier/" : @""), theComputerUUID];
    
    NSMutableDictionary *ret = [NSMutableDictionary dictionary];
    if (![self addPathsBySHA1InDirectory:objectsDir fromRemoteFS:remoteFS toDictionary:ret delegate:theDelegate error:error]) {
        return nil;
    }
    return ret;
}
- (BOOL)addPathsBySHA1InDirectory:(NSString *)theDirectory fromRemoteFS:(RemoteFS *)remoteFS toDictionary:(NSMutableDictionary *)ret delegate:(id<TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    NSDictionary *itemsByName = [remoteFS itemsByNameInDirectory:theDirectory targetConnectionDelegate:theDelegate error:error];
    if (itemsByName == nil) {
        return NO;
    }
    for (Item *item in [itemsByName allValues]) {
        if ([item.name length] == 2) {
            NSString *subdir = [theDirectory stringByAppendingPathComponent:item.name];
            NSDictionary *subdirItemsByName = [remoteFS itemsByNameInDirectory:subdir targetConnectionDelegate:theDelegate error:error];
            if (subdirItemsByName == nil) {
                return NO;
            }
            for (Item *subdirItem in [subdirItemsByName allValues]) {
                NSString *childPath = [subdir stringByAppendingPathComponent:subdirItem.name];
                if ([subdirItem.name length] == 2) {
                    NSDictionary *subsubdirItemsByName = [remoteFS itemsByNameInDirectory:childPath targetConnectionDelegate:theDelegate error:error];
                    if (subsubdirItemsByName == nil) {
                        return NO;
                    }
                    for (NSString *subsubDirName in [subsubdirItemsByName allKeys]) {
                        NSString *subsubDirPath = [childPath stringByAppendingPathComponent:subsubDirName];
                        NSString *sha1 = [NSString stringWithFormat:@"%@%@%@", item.name, subdirItem.name, subsubDirName];
                        [ret setObject:subsubDirPath forKey:sha1];
                    }
                } else if ([subdirItem.name length] == 38) {
                    NSString *sha1 = [item.name stringByAppendingString:subdirItem.name];
                    [ret setObject:childPath forKey:sha1];
                } else {
                    HSLogWarn(@"unexpected object path %@", childPath);
                }
            }
        } else if ([item.name length] == 40) {
            [ret setObject:[theDirectory stringByAppendingPathComponent:item.name] forKey:item.name];
        } else {
            HSLogWarn(@"ignoring unexpected entry %@/%@", theDirectory, item.name);
        }
    }
    return YES;
}

- (NSNumber *)freeBytesAtPath:(NSString *)thePath targetConnectionDelegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    return [[self remoteFS:error] freeBytesAtPath:(NSString *)thePath targetConnectionDelegate:theDelegate error:error];
}
- (BOOL)clearCachedItemsForDirectory:(NSString *)theDirectory error:(NSError **)error {
    RemoteFS *remoteFS = [self remoteFS:error];
    if (remoteFS == nil) {
        return NO;
    }
    return [remoteFS clearCacheForPath:theDirectory error:error];
}
- (BOOL)clearAllCachedData:(NSError **)error {
    RemoteFS *remoteFS = [self remoteFS:error];
    if (remoteFS == nil) {
        return NO;
    }
    // Delete items databases:
    if (![remoteFS clearCache:error]) {
        return NO;
    }
    NSString *cacheDir = [[UserLibrary arqCachePath] stringByAppendingPathComponent:[target targetUUID]];
    
    NSError *myError = nil;
    HSLogDetail(@"deleting cached data at %@", cacheDir);
    if ([[NSFileManager defaultManager] fileExistsAtPath:cacheDir] && ![[NSFileManager defaultManager] removeItemAtPath:cacheDir error:&myError]) {
        HSLogError(@"failed to delete %@: %@", cacheDir, myError);
        SETERRORFROMMYERROR;
        return NO;
    }
    
    return YES;
}
- (NSNumber *)chunkerVersionForComputerUUID:(NSString *)theComputerUUID delegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    NSString *path = [NSString stringWithFormat:@"%@/%@/chunker_version.dat", pathPrefix, theComputerUUID];
    NSData *data = [[self remoteFS:error] contentsOfFileAtPath:path dataTransferDelegate:nil targetConnectionDelegate:theDelegate error:error];
    if (data == nil) {
        return nil;
    }
    int32_t theChunkerVersion = 0;
    DataInputStream *dis = [[[DataInputStream alloc] initWithData:data description:@"chunker version"] autorelease];
    BufferedInputStream *bis = [[[BufferedInputStream alloc] initWithUnderlyingStream:dis] autorelease];
    if (![IntegerIO readInt32:&theChunkerVersion from:bis error:error]) {
        return nil;
    }
    return [NSNumber numberWithInteger:(NSInteger)theChunkerVersion];
}
- (BOOL)setChunkerVersion:(NSInteger)theChunkerVersion forComputerUUID:(NSString *)theComputerUUID delegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    NSMutableData *data = [NSMutableData data];
    [IntegerIO writeInt32:(int32_t)theChunkerVersion to:data];
    NSString *path = [NSString stringWithFormat:@"%@/%@/chunker_version.dat", pathPrefix, theComputerUUID];
    if (![[self remoteFS:error] createFileAtomicallyWithData:data atPath:path dataTransferDelegate:nil targetConnectionDelegate:theDelegate error:error]) {
        return NO;
    }
    return YES;
}


#pragma mark internal
- (RemoteFS *)remoteFS:(NSError **)error {
    [lock lock];
    NSNumber *threadId = [NSNumber numberWithUnsignedLongLong:(unsigned long long)pthread_self()];
    RemoteFS *ret = [remoteFSByThreadId objectForKey:threadId];
    if (ret == nil) {
        ret = [self newRemoteFS:error];
        if (ret != nil) {
            [remoteFSByThreadId setObject:ret forKey:threadId];
            [ret release];
        }
    }
    [lock unlock];
    return ret;
}
- (RemoteFS *)newRemoteFS:(NSError **)error {
    NSString *secret = [target secret:error];
    if (secret == nil) {
        return nil;
    }
    
    NSError *myError = nil;
    NSString *oauth2ClientSecret = [target oAuth2ClientSecret:&myError];
    if (oauth2ClientSecret == nil && [myError code] != ERROR_MISSING_SECRET) {
        SETERRORFROMMYERROR;
        return nil;
    }
    
    id <ItemFS> theItemFS = nil;
    TargetType targetType = [target targetType];

    if (targetType == kTargetLocal) {
        theItemFS = [[LocalItemFS alloc] initWithEndpoint:[target endpoint] error:error];
        if (theItemFS == nil) {
            return nil;
        }
        
    } else if (targetType == kTargetAWS) {
        AWSRegion *region = [AWSRegion regionWithS3Endpoint:[target endpoint]];
        if (region == nil) {
            region = [AWSRegion usEast1];
        }
        id <S3AuthorizationProvider> sap = [[S3AuthorizationProviderFactory sharedS3AuthorizationProviderFactory] providerForEndpoint:[target endpoint]
                                                                                                                            accessKey:[[target endpoint] user]
                                                                                                                            secretKey:secret
                                                                                                                     signatureVersion:[target awsRequestSignatureVersion]
                                                                                                                            awsRegion:region];
        NSString *portString = @"";
        if ([[[target endpoint] port] intValue] != 0) {
            portString = [NSString stringWithFormat:@":%d", [[[target endpoint] port] intValue]];
        }
        NSURL *s3Endpoint = [NSURL URLWithString:[NSString stringWithFormat:@"%@://%@%@", [[target endpoint] scheme], [[target endpoint] host], portString]];
        theItemFS = [[S3Service alloc] initWithS3AuthorizationProvider:sap endpoint:s3Endpoint];
        
    } else {
        SETNSERROR(@"TargetConnectionErrorDomain", -1, @"unknown target type %d", targetType);
        return nil;
    }
    
    NSAssert(theItemFS != nil, @"theItemFS may not be nil");
    
    RemoteFS *ret = [[RemoteFS alloc] initWithItemFS:theItemFS cacheUUID:[target targetUUID]];
    [theItemFS release];
    return ret;
}
@end
