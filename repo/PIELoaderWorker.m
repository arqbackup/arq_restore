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



#import "PIELoader.h"
#import "PIELoaderWorker.h"
#import "Fark.h"
#import "PackIndexGenerator.h"
#import "PackIndex.h"


@implementation PIELoaderWorker
- (id)initWithPIELoader:(PIELoader *)thePIELoader fark:(Fark *)theFark storageType:(StorageType)theStorageType {
    if (self = [super init]) {
        pieLoader = [thePIELoader retain];
        fark = theFark;
        storageType = theStorageType;
        
        [NSThread detachNewThreadSelector:@selector(run) toTarget:self withObject:nil];
    }
    return self;
}
- (void)dealloc {
    [pieLoader release];
    [super dealloc];
}

- (NSString *)errorDomain {
    return @"PIELoaderWorkerErrorDomain";
}

- (void)run {
    NSAutoreleasePool *pool = nil;
    for (;;) {
        [pool drain];
        pool = [[NSAutoreleasePool alloc] init];
        
        PackId *packId = [pieLoader nextPackId];
        if (packId == nil) {
            break;
        }
        NSError *myError = nil;
        if (![self loadPackId:packId error:&myError]) {
            HSLogDetail(@"failed to load %@: %@", packId, myError);
            if ([myError isErrorWithDomain:[self errorDomain] code:ERROR_MISSING_PACK_INDEX]) {
                HSLogInfo(@"skipping pack %@ because there is no index", packId);
            } else {
                [pieLoader errorDidOccur:myError];
            }
        }
    }
    [pieLoader workerDidFinish];
    [pool drain];
}

- (BOOL)loadPackId:(PackId *)thePackId error:(NSError **)error {
    NSError *myError = nil;
    NSData *indexData = [fark indexDataForPackId:thePackId error:&myError];
    if (indexData == nil) {
        if ([myError code] != ERROR_NOT_FOUND) {
            HSLogDebug(@"failed to get index data for %@: %@", thePackId, myError);
            SETERRORFROMMYERROR;
            return NO;
        }
        if (storageType == StorageTypeS3) {
            HSLogDebug(@"index not found for %@; attempting to rebuild it", thePackId);
            // Rebuild the index from the S3 pack:
            NSData *packData = [fark packDataForPackId:thePackId storageType:storageType error:&myError];
            if (packData == nil) {
                HSLogDebug(@"failed to load pack data for %@: %@", thePackId, myError);
                SETERRORFROMMYERROR;
                return NO;
            }
            PackIndexGenerator *pig = [[[PackIndexGenerator alloc] initWithPackId:thePackId packData:packData] autorelease];
            indexData = [pig indexData:&myError];
            if (indexData == nil) {
                HSLogDebug(@"failed to create index data from pack %@: %@", thePackId, myError);
                // Failed to read the pack. Delete the pack.
                SETERRORFROMMYERROR;
//                NSError *rmError = nil;
//                HSLogWarn(@"deleting corrupt pack that has no index: %@", thePackId);
//                if (![fark deletePack:thePackId storageType:StorageTypeS3 error:&rmError]) {
//                    HSLogError(@"failed to delete corrupt pack %@: %@", thePackId, rmError);
//                }
                return NO;
            }
            HSLogDebug(@"saving rebuilt index data for %@", thePackId);
            if (![fark putIndexData:indexData forPackId:thePackId error:&myError]) {
                SETERRORFROMMYERROR;
                HSLogDebug(@"failed to save rebuild index data for %@: %@", thePackId, myError);
                return NO;
            }
        } else {
            HSLogDebug(@"index not found for %@ and can't rebuild it", thePackId);
            // Can't load the pack in real time, so we can't rebuild an index file.
            SETNSERROR([self errorDomain], ERROR_MISSING_PACK_INDEX, @"no index for %@", thePackId);
            return NO;
        }
    }
    PackIndex *packIndex = [[[PackIndex alloc] initWithPackId:thePackId indexData:indexData] autorelease];
    NSArray *pies = [packIndex packIndexEntries:&myError];
    if (pies == nil) {
        SETERRORFROMMYERROR;
        HSLogDebug(@"failed to read pack index entries from index data for %@: %@", thePackId, myError);
        return NO;
    }
    
    [pieLoader packIndexEntries:pies wereLoadedForPackId:thePackId];
    HSLogDebug(@"successfully loaded pack index entries for %@", thePackId);
    return YES;
}

@end
