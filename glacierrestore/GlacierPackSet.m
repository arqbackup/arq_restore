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


#import "GlacierPackSet.h"
#import "PackIndexEntry.h"
#import "GlacierPackIndex.h"
#import "PackId.h"


static unsigned long long DEFAULT_MAX_PACK_FILE_SIZE_MB = 5;
static unsigned long long DEFAULT_MAX_PACK_ITEM_SIZE_BYTES = 65536;


@implementation GlacierPackSet
+ (NSString *)errorDomain {
    return @"GlacierPackSetErrorDomain";
}
+ (unsigned long long)maxPackFileSizeMB {
    return DEFAULT_MAX_PACK_FILE_SIZE_MB;
}
+ (unsigned long long)maxPackItemSizeBytes {
    return DEFAULT_MAX_PACK_ITEM_SIZE_BYTES;
}

- (id)initWithTarget:(Target *)theTarget
                  s3:(S3Service *)theS3
             glacier:(GlacierService *)theGlacier
           vaultName:(NSString *)theVaultName
        s3BucketName:(NSString *)theS3BucketName
        computerUUID:(NSString *)theComputerUUID
         packSetName:(NSString *)thePackSetName
           targetUID:(uid_t)theTargetUID
           targetGID:(uid_t)theTargetGID {
    if (self = [super init]) {
        target = [theTarget retain];
        s3 = [theS3 retain];
        glacier = [theGlacier retain];
        s3BucketName = [theS3BucketName retain];
        computerUUID = [theComputerUUID retain];
        packSetName = [thePackSetName retain];
        targetUID = theTargetUID;
        targetGID = theTargetGID;
        glacierPackIndexesByPackSHA1 = [[NSMutableDictionary alloc] init];
        packIndexEntriesByObjectSHA1 = [[NSMutableDictionary alloc] init];
    }
    return self;
}
- (void)dealloc {
    [target release];
    [s3 release];
    [glacier release];
    [s3BucketName release];
    [computerUUID release];
    [packSetName release];
    [glacierPackIndexesByPackSHA1 release];
    [packIndexEntriesByObjectSHA1 release];
    [super dealloc];
}

- (BOOL)containsBlob:(BOOL *)contains forSHA1:(NSString *)sha1 dataSize:(unsigned long long *)dataSize targetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD error:(NSError **)error {
    if (!loadedPIEs && ![self loadPackIndexEntriesWithTargetConnectionDelegate:theTCD error:error]) {
        return NO;
    }
    PackIndexEntry *pie = [packIndexEntriesByObjectSHA1 objectForKey:sha1];
    *contains = (pie != nil);
    if (pie != nil && dataSize != NULL) {
        *dataSize = [pie dataLength];
    }
    return YES;

}
- (GlacierPackIndex *)glacierPackIndexForObjectSHA1:(NSString *)theObjectSHA1 targetConnectionDelegate:(id<TargetConnectionDelegate>)theTCD error:(NSError **)error {
    PackIndexEntry *pie = [self packIndexEntryForObjectSHA1:theObjectSHA1 targetConnectionDelegate:theTCD error:error];
    return [glacierPackIndexesByPackSHA1 objectForKey:[[pie packId] packSHA1]];
}
- (PackIndexEntry *)packIndexEntryForObjectSHA1:(NSString *)theSHA1 targetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD error:(NSError **)error {
    if (!loadedPIEs && ![self loadPackIndexEntriesWithTargetConnectionDelegate:theTCD error:error]) {
        return NO;
    }
    PackIndexEntry *ret = [packIndexEntriesByObjectSHA1 objectForKey:theSHA1];
    if (ret == nil) {
        SETNSERROR([GlacierPackSet errorDomain], ERROR_NOT_FOUND, @"object %@ not found in GlacierPackSet", theSHA1);
    }
    return ret;
}


#pragma mark internal
- (BOOL)loadPackIndexEntriesWithTargetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD error:(NSError **)error {
    NSDictionary *thePackIndexEntriesByObjectSHA1 = [self packIndexEntriesBySHA1WithTargetConnectionDelegate:theTCD :error];
    if (thePackIndexEntriesByObjectSHA1 == nil) {
        return NO;
    }
    [packIndexEntriesByObjectSHA1 setDictionary:thePackIndexEntriesByObjectSHA1];
    loadedPIEs = YES;
    return YES;
}
- (NSDictionary *)packIndexEntriesBySHA1WithTargetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD :(NSError **)error {
    NSArray *glacierPackIndexes = [GlacierPackIndex glacierPackIndexesForTarget:target s3Service:s3 s3BucketName:s3BucketName computerUUID:computerUUID packSetName:packSetName targetConnectionDelegate:theTCD targetUID:targetUID targetGID:targetGID error:error];
    if (glacierPackIndexes == nil) {
        return nil;
    }
    NSMutableDictionary *packIndexEntriesBySHA1 = [NSMutableDictionary dictionary];
    for (GlacierPackIndex *index in glacierPackIndexes) {
        if (![index makeLocalWithTargetConnectionDelegate:theTCD error:error]) {
            return nil;
        }
        NSArray *pies = [index allPackIndexEntriesWithTargetConnectionDelegate:theTCD error:error];
        if (pies == nil) {
            return nil;
        }
        unsigned long long packLength = 0;
        for (PackIndexEntry *pie in pies) {
            [packIndexEntriesBySHA1 setObject:pie forKey:[pie objectSHA1]];
            
            unsigned long long endOffset = [pie offset] + [pie dataLength];
            if (endOffset > packLength) {
                packLength = endOffset;
            }
        }
    }
    
    [glacierPackIndexesByPackSHA1 removeAllObjects];
    for (GlacierPackIndex *index in glacierPackIndexes) {
        [glacierPackIndexesByPackSHA1 setObject:index forKey:[[index packId] packSHA1]];
    }
    
    return packIndexEntriesBySHA1;
}
@end
