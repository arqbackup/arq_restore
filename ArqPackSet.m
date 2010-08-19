//
//  ArqPackSet.m
//  Arq
//
//  Created by Stefan Reitshamer on 6/22/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "ArqPackSet.h"
#import "S3Service.h"
#import "RegexKitLite.h"
#import "DiskPackIndex.h"
#import "PackIndexEntry.h"
#import "SetNSError.h"
#import "NSErrorCodes.h"
#import "DiskPack.h"
#import "AppKeychain.h"
#import "S3AuthorizationProvider.h"
#import "NSError_extra.h"

#define MAX_RETRIES (10)

@interface ArqPackSet (internal)
- (ServerBlob *)newInternalServerBlobForSHA1:(NSString *)sha1 error:(NSError **)error;
- (NSDictionary *)doLoadPackIndexEntries:(NSError **)error;
@end

@implementation ArqPackSet
+ (NSString *)errorDomain {
    return @"ArqPackSetErrorDomain";
}
+ (BOOL)cachePackSetIndexesForS3BucketName:(NSString *)theS3BucketName computerUUID:(NSString *)theComputerUUID error:(NSError **)error {
    NSString *accessKeyID;
    NSString *secretAccessKey;
    if (![AppKeychain accessKeyID:&accessKeyID secretAccessKey:&secretAccessKey error:error]) {
        return NO;
    }
    S3AuthorizationProvider *sap = [[[S3AuthorizationProvider alloc] initWithAccessKey:accessKeyID secretKey:secretAccessKey] autorelease];
    S3Service *theS3 = [[[S3Service alloc] initWithS3AuthorizationProvider:sap useSSL:YES retryOnNetworkError:YES] autorelease];
    NSString *packSetsPrefix = [NSString stringWithFormat:@"/%@/%@/packsets/", theS3BucketName, theComputerUUID];
    NSArray *packPaths = [theS3 pathsWithPrefix:packSetsPrefix error:error];
    if (packPaths == nil) {
        return NO;
    }
    for (NSString *packPath in packPaths) {
        NSString *pattern = [NSString stringWithFormat:@"/%@/%@/packsets/([^/]+)/(\\w+)\\.pack",  theS3BucketName, theComputerUUID];
        NSRange sha1Range = [packPath rangeOfRegex:pattern capture:2];
        if (sha1Range.location != NSNotFound) {
            NSString *packSHA1 = [packPath substringWithRange:sha1Range];
            NSString *thePackSetName = [packPath substringWithRange:[packPath rangeOfRegex:pattern capture:1]];
            DiskPackIndex *dpi = [[[DiskPackIndex alloc] initWithS3Service:theS3 s3BucketName:theS3BucketName computerUUID:theComputerUUID packSetName:thePackSetName packSHA1:packSHA1] autorelease];
            if (![dpi makeLocal:error]) {
                return NO;
            }
        }
    }
    return YES;
}

- (id)initWithS3Service:(S3Service *)theS3
           s3BucketName:(NSString *)theS3BucketName
           computerUUID:(NSString *)theComputerUUID
            packSetName:(NSString *)thePackSetName {
    if (self = [super init]) {
        s3 = [theS3 retain];
        s3BucketName = [theS3BucketName retain];
        computerUUID = [theComputerUUID retain];
        packSetName = [thePackSetName retain];
    }
    return self;
}
- (void)dealloc {
    [s3 release];
    [s3BucketName release];
    [computerUUID release];
    [packSetName release];
    [packIndexEntries release];
    [super dealloc];
}
- (NSString *)packSetName {
    return packSetName;
}
- (BOOL)packSHA1:(NSString **)packSHA1 forPackedSHA1:(NSString *)packedSHA1 error:(NSError **)error {
    if (packIndexEntries == nil) {
        NSDictionary *entries = [self doLoadPackIndexEntries:error];
        if (entries == nil) {
            return NO;
        }
        packIndexEntries = [entries retain];
    }
    *packSHA1 = nil;
    PackIndexEntry *pie = [packIndexEntries objectForKey:packedSHA1];
    if (pie != nil) {
        *packSHA1 = [pie packSHA1];
    }
    return YES;
}
- (ServerBlob *)newServerBlobForSHA1:(NSString *)sha1 error:(NSError **)error {
    ServerBlob *sb = nil;
    NSError *myError = nil;
    NSUInteger i = 0;
    for (i = 0; i < MAX_RETRIES; i++) {
        sb = [self newInternalServerBlobForSHA1:sha1 error:&myError];
        if (sb == nil) {
            if ([myError isErrorWithDomain:[ArqPackSet errorDomain] code:ERROR_PACK_INDEX_ENTRY_NOT_RESOLVABLE]) {
                HSLogInfo(@"pack index entry not resolvable; reloading pack index entries from disk cache");
                [packIndexEntries release];
                packIndexEntries = nil;
            } else {
                break;
            }
        } else {
            break;
        }
    }
    if (sb == nil) {
        if ([myError isErrorWithDomain:[ArqPackSet errorDomain] code:ERROR_PACK_INDEX_ENTRY_NOT_RESOLVABLE]) {
            SETNSERROR([ArqPackSet errorDomain], ERROR_NOT_FOUND, @"failed %u times to load blob for sha1 %@ from pack set %@", i, sha1, packSetName);
        } else if (error != NULL) {
            *error = myError;
        }
    }
    return sb;
}
@end

@implementation ArqPackSet (internal)
- (ServerBlob *)newInternalServerBlobForSHA1:(NSString *)sha1 error:(NSError **)error {
    if (packIndexEntries == nil) {
        NSDictionary *entries = [self doLoadPackIndexEntries:error];
        if (entries == nil) {
            return nil;
        }
        packIndexEntries = [entries retain];
    }
    PackIndexEntry *pie = [packIndexEntries objectForKey:sha1];
    if (pie == nil) {
        SETNSERROR([ArqPackSet errorDomain], ERROR_NOT_FOUND, @"sha1 %@ not found in pack set %@", sha1, packSetName);
        return NO;
    }
    DiskPack *diskPack = [[DiskPack alloc] initWithS3Service:s3 s3BucketName:s3BucketName computerUUID:computerUUID packSetName:packSetName packSHA1:[pie packSHA1]];
    ServerBlob *sb = nil;
    do {
        NSError *myError = nil;
        if (![diskPack makeLocal:&myError]) {
            NSString *msg = [NSString stringWithFormat:@"error making disk pack %@ (pack set %@, computerUUID %@, s3BucketName %@) containing sha1 %@ local: %@", [pie packSHA1], packSetName, computerUUID, s3BucketName, sha1, [myError localizedDescription]];
            HSLogError(@"%@", msg);
            SETNSERROR([ArqPackSet errorDomain], ERROR_PACK_INDEX_ENTRY_NOT_RESOLVABLE, @"%@", msg);
            break;
        }
        sb = [diskPack newServerBlobForObjectAtOffset:[pie offset] error:&myError];
        if (sb == nil) {
            SETNSERROR([ArqPackSet errorDomain], ERROR_PACK_INDEX_ENTRY_NOT_RESOLVABLE, @"error reading sha1 %@ from disk pack %@ (pack set %@, computerUUID %@, s3BucketName %@): %@", sha1, [pie packSHA1], packSetName, computerUUID, s3BucketName, [myError localizedDescription]);
            break;
        }
    } while(0);
    [diskPack release];
    return sb;
}
- (NSDictionary *)doLoadPackIndexEntries:(NSError **)error {
    NSMutableDictionary *entries = [NSMutableDictionary dictionary];
    NSString *packSHA1Prefix = [NSString stringWithFormat:@"/%@/%@/packsets/%@/", s3BucketName, computerUUID, packSetName];
    NSArray *packSHA1Paths = [s3 pathsWithPrefix:packSHA1Prefix error:error];
    if (packSHA1Paths == nil) {
        return nil;
    }
    for (NSString *packSHA1Path in packSHA1Paths) {
        NSRange sha1Range = [packSHA1Path rangeOfRegex:@"/(\\w+)\\.pack$" capture:1];
        if (sha1Range.location != NSNotFound) {
            NSString *packSHA1 = [packSHA1Path substringWithRange:sha1Range];
            BOOL ret = NO;
            DiskPackIndex *index = [[DiskPackIndex alloc] initWithS3Service:s3 s3BucketName:s3BucketName computerUUID:computerUUID packSetName:packSetName packSHA1:packSHA1];
            do {
                if (![index makeLocal:error]) {
                    break;
                }
                NSArray *pies = [index allPackIndexEntries:error];
                if (pies == nil) {
                    break;
                }
                HSLogDebug(@"found %u entries in s3 pack sha1 %@ packset %@ computer %@ s3bucket %@", [pies count], packSHA1, packSetName, computerUUID, s3BucketName);
                for (PackIndexEntry *pie in pies) {
                    [entries setObject:pie forKey:[pie objectSHA1]];
                }
                ret = YES;
            } while (0);
            [index release];
            if (!ret) {
                return nil;
            }
        }
    }
    return entries;
}
@end
