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




#import "S3PIEInputStream.h"
#import "Fark.h"
#import "PackIndexEntry.h"
#import "DataInputStream.h"
#import "BufferedInputStream.h"
#import "StringIO.h"
#import "IntegerIO.h"
#import "SHA1Hash.h"


@implementation S3PIEInputStream
- (id)initWithFark:(Fark *)theFark packIds:(NSSet *)thePackIds {
    if (self = [super init]) {
        fark = [theFark retain];
        packIds = [[NSArray alloc] initWithArray:[thePackIds allObjects]];
    }
    return self;
}
- (void)dealloc {
    [fark release];
    [packIds release];
    [bis release];
    [super dealloc];
}
- (BOOL)nextPackIndexEntry:(PackIndexEntry **)pie data:(NSData **)data error:(NSError **)error {
    *pie = nil;
    *data = nil;
    while (objectIndex >= objectCount) {
        if (packIdsIndex >= [packIds count]) {
            return YES;
        }
        if (![self loadNextPack:error]) {
            return NO;
        }
    }
    uint64_t offset = [bis bytesReceived];
    NSString *mimeType;
    NSString *name;
    uint64_t length;
    
    HSLogDebug(@"reading entry %qu from pack %@ at offset %qu", objectIndex, currentPackId, offset);
    if (![StringIO read:&mimeType from:bis error:error] || ![StringIO read:&name from:bis error:error] || ![IntegerIO readUInt64:&length from:bis error:error]) {
        if (error != NULL) {
            HSLogError(@"error reading entry from pack %@ at offset %qu: %@", currentPackId, offset, *error);
        }
        return NO;
    }
    NSData *blobData = [bis readExactly:length error:error];
    if (blobData == nil) {
        return NO;
    }
    NSString *objectSHA1 = [SHA1Hash hashData:blobData];
    *pie = [[[PackIndexEntry alloc] initWithPackId:currentPackId offset:offset dataLength:[blobData length] objectSHA1:objectSHA1] autorelease];
    *data = blobData;
    objectIndex++;
    return YES;
}
- (BOOL)loadNextPack:(NSError **)error {
    [currentPackId release];
    currentPackId = [[packIds objectAtIndex:packIdsIndex++] retain];
    NSData *packData = [fark packDataForPackId:currentPackId storageType:StorageTypeS3 error:error];
    if (packData == nil) {
        return NO;
    }
    
    HSLogDebug(@"reading pack data for %@", currentPackId);
    
    DataInputStream *dis = [[[DataInputStream alloc] initWithData:packData description:[currentPackId description]] autorelease];
    [bis release];
    bis = [[BufferedInputStream alloc] initWithUnderlyingStream:dis];
    
    uint32_t packSig;
    uint32_t packVersion;
    if (![IntegerIO readUInt32:&packSig from:bis error:error] || ![IntegerIO readUInt32:&packVersion from:bis error:error]) {
        return NO;
    }
    if (packSig != 0x5041434b) { // "PACK"
        SETNSERROR(@"PackErrorDomain", -1, @"invalid pack signature");
        return NO;
    }
    if (packVersion != 2) {
        SETNSERROR(@"PackErrorDomain", -1, @"invalid pack version");
    }
    
    HSLogDebug(@"reading object count from pack");
    
    // Older packs had a 32-bit object count; newer packs have a 64-bit object count. Yikes!
    // We're assuming here that no pack has an object count of greater than 2^32 - 1 (4,294,967,295).
    uint32_t theObjectCount = 0;
    if (![IntegerIO readUInt32:&theObjectCount from:bis error:error]) {
        return NO;
    }
    if (theObjectCount == 0) {
        HSLogDebug(@"%@ has a 64-bit object count", currentPackId);
        
        // The first 32 bits are 0, so it must be a 64-bit object count.
        if (![IntegerIO readUInt32:&theObjectCount from:bis error:error]) {
            return NO;
        }
    } else {
        HSLogDebug(@"%@ has a 32-bit object count", currentPackId);
    }
    
    objectCount = theObjectCount;
    HSLogDebug(@"object count for %@: %qu", currentPackId, objectCount);
    if (objectCount == 0) {
        HSLogWarn(@"unexpected object count of 0 for %@", currentPackId);
    }
    objectIndex = 0;
    return YES;
}
@end
