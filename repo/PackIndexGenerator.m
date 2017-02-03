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



#import "PackIndexGenerator.h"
#import "DataInputStream.h"
#import "BufferedInputStream.h"
#import "IntegerIO.h"
#import "StringIO.h"
#import "SHA1Hash.h"
#import "NSString_extra.h"


@implementation PackIndexGenerator
- (id)initWithPackId:(PackId *)thePackId packData:(NSData *)thePackData {
    if (self = [super init]) {
        packId = [thePackId retain];
        packData = [thePackData retain];
    }
    return self;
}
- (void)dealloc {
    [packId release];
    [packData release];
    [super dealloc];
}

- (NSString *)errorDomain {
    return @"PackIndexGeneratorErrorDomain";
}

- (NSData *)indexData:(NSError **)error {
    NSError *myError = nil;
    NSData *ret = [self doIndexData:&myError];
    if (ret == nil) {
        SETNSERROR([self errorDomain], -1, @"failed to recreate index from pack %@: %@", packId, [myError localizedDescription]);
    }
    return ret;
}
- (NSData *)doIndexData:(NSError **)error {
    DataInputStream *dis = [[[DataInputStream alloc] initWithData:packData description:@"pack"] autorelease];
    BufferedInputStream *bis = [[[BufferedInputStream alloc] initWithUnderlyingStream:dis] autorelease];
    NSMutableData *indexData = [NSMutableData data];
    [IntegerIO writeUInt32:0xff744f63 to:indexData]; // Magic number
    [IntegerIO writeUInt32:0x00000002 to:indexData]; // Version 2
    
    uint32_t packLabel = 0;
    if (![IntegerIO readUInt32:&packLabel from:bis error:error]) {
        return nil;
    }
    if (packLabel != 0x5041434b) {
        SETNSERROR([self errorDomain], -1, @"PACK header doesn't say 'PACK'");
        return nil;
    }
    uint32_t packVersion = 0;
    if (![IntegerIO readUInt32:&packVersion from:bis error:error]) {
        return nil;
    }
    if (packVersion != 2) {
        SETNSERROR([self errorDomain], -1, @"unknown pack version %ld", (unsigned long)packVersion);
        return nil;
    }
    uint64_t objectCount = 0;
    if (![IntegerIO readUInt64:&objectCount from:bis error:error]) {
        return nil;
    }
    
    NSMutableDictionary *lengthsBySHA1 = [NSMutableDictionary dictionary];
    for (uint64_t index = 0; index < objectCount; index++) {
        NSString *mimeType;
        NSString *downloadName;
        if (![StringIO read:&mimeType from:bis error:error] || ![StringIO read:&downloadName from:bis error:error]) {
            return nil;
        }
        uint64_t dataLen = 0;
        if (![IntegerIO readUInt64:&dataLen from:bis error:error]) {
            return nil;
        }
        NSData *data = nil;
        if (dataLen > 0) {
            unsigned char *buf = (unsigned char *)malloc((size_t)dataLen);
            if (![bis readExactly:(NSUInteger)dataLen into:buf error:error]) {
                free(buf);
                return nil;
            }
            data = [NSData dataWithBytesNoCopy:buf length:(NSUInteger)dataLen];
        } else {
            data = [NSData data];
        }
        NSString *sha1 = [SHA1Hash hashData:data];
        [lengthsBySHA1 setObject:[NSNumber numberWithUnsignedLongLong:dataLen] forKey:sha1];
    }
    NSMutableArray *sortedKeys = [NSMutableArray arrayWithArray:[lengthsBySHA1 allKeys]];
    [sortedKeys sortUsingSelector:@selector(compare:)];
    
    // Set fanout table values.
    uint32_t fanoutTable[256];
    memset(fanoutTable, 0, sizeof(fanoutTable));
    for (NSUInteger index = 0; index < [sortedKeys count]; index++) {
        NSString *sha1 = [sortedKeys objectAtIndex:index];
        NSData *sha1HexData = [sha1 hexStringToData:error];
        if (sha1HexData == nil) {
            return nil;
        }
        if ([sha1HexData length] != 20) {
            SETNSERROR([self errorDomain], -1, @"invalid SHA1 '%@' (must be 20 bytes)", sha1);
            return nil;
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
        [IntegerIO writeUInt32:fanoutTable[index] to:indexData];
    }
    uint64_t offset = (uint64_t)16;
    for (NSUInteger index = 0; index < [sortedKeys count]; index++) {
        NSString *sha1 = [sortedKeys objectAtIndex:index];
        uint64_t length = [[lengthsBySHA1 objectForKey:sha1] unsignedLongLongValue];
        
        // Write offset to index.
        [IntegerIO writeUInt64:offset to:indexData];
        
        // Write data length to index.
        [IntegerIO writeUInt64:length to:indexData];
        
        // Write 20-byte sha1 to index.
        NSData *sha1Data = [sha1 hexStringToData:error];
        if (sha1Data == nil) {
            return nil;
        }
        [indexData appendBytes:[sha1Data bytes] length:[sha1Data length]];
        
        // Write 4 bytes (for alignment) to index.
        [IntegerIO writeUInt32:0 to:indexData];
        
        offset += 1; // 1 byte for the nil mimeType stored in the pack
        offset += 1; // 1 byte for the nil downloadName stored in the pack
        offset += 8; // 8 bytes for the data length stored in the pack
        offset += length;
    }
    return indexData;
}
@end
