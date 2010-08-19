//
//  PackIndexWriter.m
//  Arq
//
//  Created by Stefan Reitshamer on 3/3/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "PackIndexWriter.h"
#import "DiskPack.h"
#import "FileInputStream.h"
#import "FileOutputStream.h"
#import "IntegerIO.h"
#import "StringIO.h"
#import "SetNSError.h"
#import "SHA1Hash.h"
#import "NSString_extra.h"
#import "PackIndexEntry.h"

@interface PackIndexWriter (internal)
- (BOOL)writeEntries:(NSArray *)entries toStream:(id <OutputStream>)os error:(NSError **)error;
@end

@implementation PackIndexWriter
- (id)initWithPack:(DiskPack *)theDiskPack destination:(NSString *)theDestination {
    if (self = [super init]) {
        diskPack = [theDiskPack retain];
        destination = [theDestination copy];
    }
    return self;
}
- (void)dealloc {
    [diskPack release];
    [destination release];
    [super dealloc];
}
- (BOOL)writeIndex:(NSError **)error {
    NSArray *entries = [diskPack sortedPackIndexEntries:error];
    if (entries == nil) {
        return NO;
    }
    FileOutputStream *fos = [[FileOutputStream alloc] initWithPath:destination append:NO];
    BOOL ret = [self writeEntries:entries toStream:fos error:error];
    [fos release];
    if (!ret) {
        return NO;
    }
    NSString *indexSHA1 = [SHA1Hash hashFile:destination error:error];
    NSData *sha1Data = [indexSHA1 hexStringToData];
    fos = [[FileOutputStream alloc] initWithPath:destination append:YES];
    ret = [fos write:[sha1Data bytes] length:[sha1Data length] error:error];
    [fos release];
    return ret;
}
@end

@implementation PackIndexWriter (internal)
- (BOOL)writeEntries:(NSArray *)entries toStream:(id <OutputStream>)os error:(NSError **)error {
    // Write header to index.
    if (![IntegerIO writeUInt32:0xff744f63 to:os error:error]) { // Magic number.
        return NO;
    }
    if (![IntegerIO writeUInt32:0x00000002 to:os error:error]) { // Version 2.
        return NO;
    }
    unsigned int firstByte = 0;
    NSUInteger index = 0;
    for (index = 0; index < [entries count]; index++) {
        PackIndexEntry *pie = [entries objectAtIndex:index];
        NSData *sha1Hex = [[pie objectSHA1] hexStringToData];
        unsigned char myFirstByte = ((unsigned char *)[sha1Hex bytes])[0];
        while ((unsigned int)myFirstByte > firstByte) {
            if (![IntegerIO writeUInt32:index to:os error:error]) {
                return NO;
            }
            firstByte++;
        }
    }
    while (firstByte <= 0xff) {
        if (![IntegerIO writeUInt32:index to:os error:error]) {
            return NO;
        }
        firstByte++;
    }
    for (index = 0; index < [entries count]; index++) {
        PackIndexEntry *pie = [entries objectAtIndex:index];
        if (![IntegerIO writeUInt64:[pie offset] to:os error:error]
            || ![IntegerIO writeUInt64:[pie dataLength] to:os error:error]) {
            return NO;
        }
        // Write sha1 to index.
        NSData *sha1Data = [[pie objectSHA1] hexStringToData];
        if (![os write:[sha1Data bytes] length:[sha1Data length] error:error]) {
            break;
        }
        // Write 4 bytes (for alignment) to index.
        if (![IntegerIO writeUInt32:0 to:os error:error]) {
            return NO;
        }
    }
    return YES;
}
@end
