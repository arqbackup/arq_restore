/*
 Copyright (c) 2009, Stefan Reitshamer http://www.haystacksoftware.com
 
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

#import "PackSet.h"
#import "S3Service.h"
#import "SHA1Hash.h"
#import "S3ObjectReceiver.h"
#import "SetNSError.h"
#import "DataInputStream.h"
#import "PackSetSet.h"
#import "NSData-InputStream.h"
#import "ServerBlob.h"
#import "NSErrorCodes.h"
#import "DiskPackIndex.h"
#import "PackIndexEntry.h"
#import "DiskPack.h"
#import "RegexKitLite.h"
#import "HTTP.h"

static unsigned long long DEFAULT_MAX_PACK_FILE_SIZE_MB = 10;
static unsigned long long DEFAULT_MAX_PACK_ITEM_SIZE_BYTES = 65536;
static double DEFAULT_MAX_REUSABLE_PACK_FILE_SIZE_FRACTION = 0.6;



@interface PackSet (internal)
+ (unsigned long long)maxReusablePackFileSizeBytes;
- (BOOL)loadPackIndexEntries:(NSString *)packSHA1 totalDataSize:(unsigned long long *)totalDataSize error:(NSError **)error;
- (PackIndexEntry *)packIndexEntryForObjectSHA1:(NSString *)objectSHA1 error:(NSError **)error;
- (PackIndexEntry *)packIndexEntryForObjectSHA1:(NSString *)objectSHA1 inPackSHA1:(NSString *)packSHA1 error:(NSError **)error;
@end

@implementation PackSet
+ (NSString *)errorDomain {
    return @"PackSetErrorDomain";
}
+ (unsigned long long)maxPackFileSizeMB {
    return DEFAULT_MAX_PACK_FILE_SIZE_MB;
}
+ (unsigned long long)maxPackItemSizeBytes {
    return DEFAULT_MAX_PACK_ITEM_SIZE_BYTES;
}
+ (NSString *)s3PathWithS3BucketName:(NSString *)theS3BucketName computerUUID:(NSString *)theComputerUUID packSetName:(NSString *)thePackSetName {
    return [NSString stringWithFormat:@"%@/%@", [PackSetSet s3PathWithS3BucketName:theS3BucketName computerUUID:theComputerUUID], [thePackSetName stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
}
+ (NSString *)localPathWithComputerUUID:(NSString *)theComputerUUID packSetName:(NSString *)thePackSetName {
    return [NSString stringWithFormat:@"%@/%@", [PackSetSet localPathWithComputerUUID:theComputerUUID], [thePackSetName stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
}
- (id)initWithName:(NSString *)thePackSetName 
         s3Service:(S3Service *)theS3 
      s3BucketName:(NSString *)theS3BucketName 
      computerUUID:(NSString *)theComputerUUID 
    keepPacksLocal:(BOOL)isKeepPacksLocal 
         packSHA1s:(NSArray *)thePackSHA1s 
             error:(NSError **)error {
    if (self = [super init]) {
        packSetName = [thePackSetName copy];
        s3 = [theS3 retain];
        s3BucketName = [theS3BucketName copy];
        computerUUID = [theComputerUUID copy];
        keepPacksLocal = isKeepPacksLocal;
        escapedPackSetName = [[thePackSetName stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding] copy];
        packSetDir = [[PackSet localPathWithComputerUUID:theComputerUUID packSetName:packSetName] retain];
        packSHA1s = [[NSMutableSet alloc] initWithArray:thePackSHA1s];
        packIndexEntries = [[NSMutableDictionary alloc] init];
        for (NSString *packSHA1 in packSHA1s) {
            unsigned long long totalDataSize = 0;
            if (![self loadPackIndexEntries:packSHA1 totalDataSize:&totalDataSize error:error]) {
                [self release];
                return nil;
            }
            if (totalDataSize < [PackSet maxReusablePackFileSizeBytes] && currentPackSHA1 == nil) {
                currentPackSHA1 = [packSHA1 copy];
            }
        }
    }
    return self;
}
- (void)dealloc {
    [packSetName release];
    [escapedPackSetName release];
    [packSetDir release];
    [s3 release];
    [s3BucketName release];
    [computerUUID release];
    [packSHA1s release];
    [packIndexEntries release];
    [currentPackSHA1 release];
    [super dealloc];
}
- (NSString *)name {
    return packSetName;
}
- (ServerBlob *)newServerBlobForSHA1:(NSString *)sha1 error:(NSError **)error {
    HSLogTrace(@"packset %@ looking for SHA1 %@", packSetName, sha1);
    NSError *myError = nil;
    PackIndexEntry *entry = [self packIndexEntryForObjectSHA1:sha1 error:&myError];
    if (entry == nil && [myError code] != ERROR_NOT_FOUND) {
        if (error != NULL) {
            *error = myError;
        }
        HSLogError(@"error reading pack index entry for %@ from pack set %@: %@", sha1, packSetName, [myError localizedDescription]);
        return nil;
    }
    if (entry != nil) {
        NSError *myError = nil;
        DiskPack *diskPack = [[DiskPack alloc] initWithS3Service:s3 s3BucketName:s3BucketName computerUUID:computerUUID packSetName:packSetName packSHA1:[entry packSHA1]];
        if (![diskPack makeLocal:&myError]) {
            [diskPack release];
            if ([[myError domain] isEqualToString:[S3Service errorDomain]] && [myError code] == HTTP_NOT_FOUND) {
                SETNSERROR(@"PackSetErrorDomain", ERROR_NOT_FOUND, @"pack %@ not found in S3: %@", [entry packSHA1], [myError localizedDescription]);
            } else if (error != NULL) {
                *error = myError;
            }
            return nil;
        }
        ServerBlob *sb = [diskPack newServerBlobForObjectAtOffset:[entry offset] error:error];
        [diskPack release];
        return sb;
    }
    SETNSERROR(@"PackErrorDomain", ERROR_NOT_FOUND, @"sha1 %@ not found", sha1);
    return nil;
}
- (BOOL)containsBlobForSHA1:(NSString *)sha1 {
    return [packIndexEntries objectForKey:sha1] != nil;
}
@end

@implementation PackSet (internal)
+ (unsigned long long)maxReusablePackFileSizeBytes {
    return (unsigned long long)((double)([PackSet maxPackFileSizeMB] * 1000000) * DEFAULT_MAX_REUSABLE_PACK_FILE_SIZE_FRACTION);
}
- (PackIndexEntry *)packIndexEntryForObjectSHA1:(NSString *)objectSHA1 error:(NSError **)error {
    PackIndexEntry *pie = [packIndexEntries objectForKey:objectSHA1];
    if (pie == nil) {
        SETNSERROR(@"PackErrorDomain", ERROR_NOT_FOUND, @"pie not found for %@", objectSHA1);
    }
    return pie;
}
- (PackIndexEntry *)packIndexEntryForObjectSHA1:(NSString *)objectSHA1 inPackSHA1:(NSString *)packSHA1 error:(NSError **)error {
    PackIndexEntry *pie = [packIndexEntries objectForKey:objectSHA1];
    if (pie == nil) {
        SETNSERROR(@"PackErrorDomain", ERROR_NOT_FOUND, @"pie not found for %@", objectSHA1);
    }
    return pie;
}
- (BOOL)loadPackIndexEntries:(NSString *)packSHA1 totalDataSize:(unsigned long long *)totalDataSize error:(NSError **)error {
    *totalDataSize = 0;
    DiskPackIndex *index = [[DiskPackIndex alloc] initWithS3Service:s3 s3BucketName:s3BucketName computerUUID:computerUUID packSetName:packSetName packSHA1:packSHA1];
    BOOL ret = NO;
    do {
        if (![index makeLocal:error]) {
            break;
        }
        NSArray *pies = [index allPackIndexEntries:error];
        if (pies == nil) {
            break;
        }
        for (PackIndexEntry *pie in pies) {
            [packIndexEntries setObject:pie forKey:[pie objectSHA1]];
            unsigned long long dataEndOffset = [pie offset] + [pie dataLength];
            if (dataEndOffset > *totalDataSize) {
                *totalDataSize = dataEndOffset;
            }
        }
        ret = YES;
    } while (0);
    [index release];
    return ret;
}
@end
