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



#import "ArqSalt.h"
#import "NSFileManager_extra.h"
#import "UserLibrary_Arq.h"
#import "Target.h"
#import "TargetConnection.h"
#import "Streams.h"
#import "CacheOwnership.h"


#define SALT_LENGTH (8)


@implementation ArqSalt
- (id)initWithTarget:(Target *)theTarget
        computerUUID:(NSString *)theComputerUUID
               error:(NSError **)error {
    if (theComputerUUID == nil) {
        SETNSERROR([self errorDomain], ERROR_NOT_FOUND, @"no computer UUID given for salt file");
        return nil;
    }
    
    if (self = [super init]) {
        target = [theTarget retain];
        computerUUID = [theComputerUUID retain];
    }
    return self;
}
- (void)dealloc {
    [target release];
    [computerUUID release];
    [super dealloc];
}

- (NSString *)errorDomain {
    return @"ArqSaltErrorDomain";
}

- (BOOL)ensureSaltExistsAtTargetWithTargetConnectionDelegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    TargetConnection *targetConnection = [target newConnection:error];
    if (targetConnection == nil) {
        return NO;
    }
    BOOL ret = [self ensureSaltExistsAtTargetWithTargetConnection:targetConnection targetConnectionDelegate:theDelegate error:error];
    [targetConnection release];
    return ret;
}
- (BOOL)ensureSaltExistsAtTargetWithTargetConnection:(TargetConnection *)targetConnection targetConnectionDelegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    NSError *myError = nil;
    NSData *saltData = [targetConnection saltDataForComputerUUID:computerUUID delegate:theDelegate error:&myError];
    if (saltData == nil) {
        if ([myError code] != ERROR_NOT_FOUND) {
            HSLogError(@"error getting salt from target: %@", myError);
            SETERRORFROMMYERROR;
            return NO;
        }
        
        
        // Try to replace salt file with file from cache.
        
        saltData = [NSData dataWithContentsOfFile:[self localPath] options:NSUncachedRead error:&myError];
        if (saltData == nil) {
            if ([myError code] != ERROR_NOT_FOUND) {
                HSLogError(@"error reading cached salt file: %@", myError);
            }
            SETNSERROR([self errorDomain], -1, @"salt data not found at target or in cache");
            return NO;
        }
        
        if (![targetConnection setSaltData:saltData forComputerUUID:computerUUID delegate:theDelegate error:error]) {
            return NO;
        }
    }
    return YES;
}
- (NSData *)saltDataWithTargetConnectionDelegate:(id<TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    NSData *ret = [NSData dataWithContentsOfFile:[self localPath] options:NSUncachedRead error:error];
    if (ret == nil) {
        ret = [self saltFromTargetWithTargetConnectionDelegate:theDelegate error:error];
    }
    return ret;
}


#pragma mark internal
- (NSData *)createRandomSalt {
    unsigned char buf[SALT_LENGTH];
    for (NSUInteger i = 0; i < SALT_LENGTH; i++) {
        buf[i] = (unsigned char)arc4random_uniform(256);
    }
    return [[[NSData alloc] initWithBytes:buf length:SALT_LENGTH] autorelease];
}
- (NSString *)localPath {
    return [NSString stringWithFormat:@"%@/%@/%@/salt.dat", [UserLibrary arqCachePath], [target targetUUID], computerUUID];
}
- (NSData *)saltFromTargetWithTargetConnectionDelegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    NSData *ret = nil;
    TargetConnection *targetConnection = [target newConnection:error];
    if (targetConnection == nil) {
        return nil;
    }
    ret = [targetConnection saltDataForComputerUUID:computerUUID delegate:theDelegate error:error];
    if (ret != nil) {
        NSError *myError = nil;
        if (![[NSFileManager defaultManager] ensureParentPathExistsForPath:[self localPath] targetUID:[[CacheOwnership sharedCacheOwnership] uid] targetGID:[[CacheOwnership sharedCacheOwnership] gid] error:&myError]
            || ![Streams writeData:ret atomicallyToFile:[self localPath] targetUID:[[CacheOwnership sharedCacheOwnership] uid] targetGID:[[CacheOwnership sharedCacheOwnership] gid] bytesWritten:NULL error:&myError]) {
            HSLogError(@"error caching salt data to %@: %@", [self localPath], myError);
        }
    }
    [targetConnection release];
    return ret;
}
@end
