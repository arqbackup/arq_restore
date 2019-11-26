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




#import "PackBuilder.h"
#import "DataOutputStream.h"
#import "BufferedOutputStream.h"
#import "StringIO.h"
#import "IntegerIO.h"
#import "Fark.h"
#import "PackIndexGenerator.h"
#import "PackIndex.h"
#import "PackIndexEntry.h"
#import "SHA1Hash.h"
#import "NSString_extra.h"
#import "PackId.h"
#import "DataInputStream.h"
#import "BufferedInputStream.h"
#import "PackBuilderEntry.h"


@implementation PackBuilder
- (id)init {
    NSAssert(1==0, @"can't call this init method!");
    return nil;
}
- (id)initWithFark:(Fark *)theFark
       storageType:(StorageType)theStorageType
       packSetName:(NSString *)thePackSetName
            buffer:(NSMutableData *)theBuffer
  cachePackFilesToDisk:(BOOL)theCachePackFilesToDisk {
    if (self = [super init]) {
        fark = [theFark retain];
        storageType = theStorageType;
        packSetName = [thePackSetName retain];
        buffer = [theBuffer retain];
        [buffer setLength:0];
        cachePackFilesToDisk = theCachePackFilesToDisk;
        entriesBySHA1 = [[NSMutableDictionary alloc] init];
    }
    return self;
}
- (void)dealloc {
#ifdef DEBUG
    NSAssert(!modified, @"modified must be NO in PackBuilder dealloc");
#else
    if ([self size] > 0 && modified) {
        HSLogError(@"PackBuilder was modified but not committed! contains %ld entries", [entriesBySHA1 count]);
    }
#endif
    [fark release];
    [packSetName release];
    [buffer release];
    [entriesBySHA1 release];
    [super dealloc];
}

- (NSString *)errorDomain {
    return @"PackBuilderErrorDomain";
}
- (BOOL)containsObjectForSHA1:(NSString *)sha1 {
    NSData *data = [entriesBySHA1 objectForKey:sha1];
    return data != nil;
}
- (NSData *)dataForSHA1:(NSString *)theSHA1 error:(NSError **)error {
    PackBuilderEntry *entry = [entriesBySHA1 objectForKey:theSHA1];
    if (entry == nil) {
        SETNSERROR([self errorDomain], ERROR_NOT_FOUND, @"object not found for %@ in pack builder", theSHA1);
        return nil;
    }
    return [buffer subdataWithRange:NSMakeRange([entry offset], [entry length])];
}
- (void)addData:(NSData *)theData forSHA1:(NSString *)sha1 {
    if ([entriesBySHA1 objectForKey:sha1] == nil) {
        PackBuilderEntry *entry = [[[PackBuilderEntry alloc] initWithOffset:[buffer length] length:[theData length]] autorelease];
        [buffer appendBytes:[theData bytes] length:[theData length]];
        [entriesBySHA1 setObject:entry forKey:sha1];
        modified = YES;
        HSLogDebug(@"added blob for sha1 %@ to pack builder", sha1);
    }
}
- (void)removeDataForSHA1:(NSString *)sha1 {
    if ([entriesBySHA1 objectForKey:sha1] != nil) {
        [entriesBySHA1 removeObjectForKey:sha1];
    }
}
- (uint64_t)size {
    return [buffer length];
}
- (NSArray *)sha1s {
    return [entriesBySHA1 allKeys];
}
- (BOOL)isModified {
    return modified;
}
- (PackId *)commit:(NSError **)error {
    if (error != NULL) {
        *error = nil;
    }
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    PackId *ret = [self doCommit:error];
    [ret retain];
    if (error != NULL) {
        [*error retain];
    }
    [pool drain];
    [ret autorelease];
    if (error != NULL) {
        [*error autorelease];
    }
    modified = NO;
    return ret;
}
- (PackId *)doCommit:(NSError **)error {
    unsigned long entryCount = [entriesBySHA1 count];
    
    NSMutableData *indexData = [NSMutableData data];
    NSMutableData *packData = [NSMutableData data];
    
    BufferedOutputStream *indexBOS = [[[BufferedOutputStream alloc] initWithMutableData:indexData] autorelease];
    BufferedOutputStream *packBOS = [[[BufferedOutputStream alloc] initWithMutableData:packData] autorelease];
    if (![self writeIndex:indexBOS pack:packBOS error:error]) {
        return nil;
    }
    if (![indexBOS flush:error] || ![packBOS flush:error]) {
        return nil;
    }
    
    // Append SHA1 of the index data to the end of the index:
    NSData *indexHashBytes = [[SHA1Hash hashData:indexData] hexStringToData:error];
    if (indexHashBytes == nil) {
        return nil;
    }
    [indexData appendData:indexHashBytes];
    // Append SHA1 of the pack data to the end of the pack data:
    NSData *packHashBytes = [[SHA1Hash hashData:packData] hexStringToData:error];
    if (packHashBytes == nil) {
        return nil;
    }
    [packData appendData:packHashBytes];
    
    NSString *packSHA1 = [SHA1Hash hashData:packData];
    PackId *thePackId = [[[PackId alloc] initWithPackSetName:packSetName packSHA1:packSHA1] autorelease];
    
    // Write pack to fark before index, in case there's a problem.
    if (![fark putPackData:packData forPackId:thePackId storageType:storageType saveToCache:cachePackFilesToDisk error:error]) {
        return nil;
    }
    if (![fark putIndexData:indexData forPackId:thePackId error:error]) {
        return nil;
    }
    HSLogInfo(@"wrote %ld entr%@ to pack %@", (unsigned long)entryCount, (entryCount == 1 ? @"y" : @"ies"), thePackId);
    
    return thePackId;
}
- (BOOL)writeIndex:(BufferedOutputStream *)indexBOS pack:(BufferedOutputStream *)packBOS error:(NSError **)error {
    NSMutableArray *sortedKeys = [NSMutableArray arrayWithArray:[entriesBySHA1 allKeys]];
    [sortedKeys sortUsingSelector:@selector(compare:)];
    
    // Write header to index.
    if (![IntegerIO writeUInt32:0xff744f63 to:indexBOS error:error]) { // Magic number.
        return NO;
    }
    if (![IntegerIO writeUInt32:0x00000002 to:indexBOS error:error]) { // Version 2.
        return NO;
    }
    
    // Write header to pack.
    if (![IntegerIO writeUInt32:0x5041434b to:packBOS error:error]) { // "PACK"
        return NO;
    }
    if (![IntegerIO writeUInt32:0x00000002 to:packBOS error:error]) { // Version 2.
        return NO;
    }
    
    // Write object count to pack.
    if (![IntegerIO writeUInt64:(uint64_t)[sortedKeys count] to:packBOS error:error]) {
        return NO;
    }
    
    // Set fanout table values.
    uint32_t fanoutTable[256];
    memset(fanoutTable, 0, sizeof(fanoutTable));
    for (NSUInteger index = 0; index < [sortedKeys count]; index++) {
        NSString *sha1 = [sortedKeys objectAtIndex:index];
        NSData *sha1HexData = [sha1 hexStringToData:error];
        if (sha1HexData == nil) {
            return NO;
        }
        unsigned char firstSHA1Byte = ((unsigned char *)[sha1HexData bytes])[0];
        // Increment fanoutTable entry.
        fanoutTable[firstSHA1Byte] += 1;
    }
    // Accumulate fanout numbers.
    uint32_t fanoutTotal = 0;
    for (uint32_t index = 0; index < 256; index++) {
        fanoutTotal += fanoutTable[index];
        fanoutTable[index] = fanoutTotal;
    }
    // Write fanout table to index.
    for (uint32_t index = 0; index < 256; index++) {
        if (![IntegerIO writeUInt32:fanoutTable[index] to:indexBOS error:error]) {
            return NO;
        }
    }
    
    unsigned char *buf = (unsigned char *)[buffer bytes];
    
    // Write pack data and packindex data.
    for (NSUInteger index = 0; index < [sortedKeys count]; index++) {
        NSString *sha1 = [sortedKeys objectAtIndex:index];
        PackBuilderEntry *entry = [entriesBySHA1 objectForKey:sha1];
        
        uint64_t offset = [packBOS bytesWritten];
        
        // Write offset to index.
        if (![IntegerIO writeUInt64:offset to:indexBOS error:error]) {
            return NO;
        }
        // Write data length to index.
        if (![IntegerIO writeUInt64:(uint64_t)[entry length] to:indexBOS error:error]) {
            return NO;
        }
        // Write sha1 to index.
        NSData *sha1Data = [sha1 hexStringToData:error];
        if (sha1Data == nil) {
            return NO;
        }
        if (![indexBOS writeFully:[sha1Data bytes] length:[sha1Data length] error:error]) {
            return NO;
        }
        // Write 4 bytes (for alignment) to index.
        if (![IntegerIO writeUInt32:0 to:indexBOS error:error]) {
            return NO;
        }
        
        // Write mime type to pack.
        if (![StringIO write:nil to:packBOS error:error]) {
            return NO;
        }
        // Write download name to pack.
        if (![StringIO write:nil to:packBOS error:error]) {
            return NO;
        }
        // Write 8-byte data length to pack.
        if (![IntegerIO writeUInt64:(uint64_t)[entry length] to:packBOS error:error]) {
            return NO;
        }
        // Write data to pack.
        if (![packBOS writeFully:(buf + [entry offset]) length:[entry length] error:error]) {
            return NO;
        }
        
    }
    return YES;
}
@end
