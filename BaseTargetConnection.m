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


#import "Target.h"
#import "RemoteFS.h"
#import "BaseTargetConnection.h"
#import "RegexKitLite.h"
#import "TargetConnection.h"


@implementation BaseTargetConnection
- (id)initWithTarget:(Target *)theTarget remoteFS:(id<RemoteFS>)theRemoteFS {
    if (self = [super init]) {
        target = [theTarget retain];
        remoteFS = [theRemoteFS retain];
        
        if ([[[theTarget endpoint] path] isEqualToString:@"/"]) {
            pathPrefix = [@"" retain];
        } else {
            pathPrefix = [[[theTarget endpoint] path] retain];
        }
    }
    return self;
}
- (void)dealloc {
    [target release];
    [remoteFS release];
    [pathPrefix release];
    [super dealloc];
}

- (NSArray *)computerUUIDsWithDelegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    NSArray *computerUUIDs = [remoteFS contentsOfDirectoryAtPath:[[target endpoint] path] targetConnectionDelegate:theDelegate error:error];
    if (computerUUIDs == nil) {
        return nil;
    }
    
    NSMutableArray *ret = [NSMutableArray array];
    for (NSString *computerUUID in computerUUIDs) {
        if ([computerUUID rangeOfRegex:@"^(\\S{8}-\\S{4}-\\S{4}-\\S{4}-\\S{12})$"].location != NSNotFound) {
            [ret addObject:computerUUID];
        }
    }
    return ret;
}

- (NSArray *)bucketUUIDsForComputerUUID:(NSString *)theComputerUUID deleted:(BOOL)deleted delegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    NSString *subdir = deleted ? @"deletedbuckets" : @"buckets";
    NSString *bucketsPrefix = [NSString stringWithFormat:@"%@/%@/%@/", pathPrefix, theComputerUUID, subdir];
    NSArray *bucketUUIDs = [remoteFS contentsOfDirectoryAtPath:bucketsPrefix targetConnectionDelegate:theDelegate error:error];
    if (bucketUUIDs == nil) {
        return nil;
    }
    
    NSMutableArray *ret = [NSMutableArray array];
    for (NSString *bucketUUID in bucketUUIDs) {
        if ([bucketUUID rangeOfRegex:@"^(\\S{8}-\\S{4}-\\S{4}-\\S{4}-\\S{12})$"].location != NSNotFound) {
            [ret addObject:bucketUUID];
        }
    }
    return ret;
}

- (NSData *)bucketPlistDataForComputerUUID:(NSString *)theComputerUUID bucketUUID:(NSString *)theBucketUUID deleted:(BOOL)deleted delegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    NSString *subdir = deleted ? @"deletedbuckets" : @"buckets";
    NSString *path = [NSString stringWithFormat:@"%@/%@/%@/%@", pathPrefix, theComputerUUID, subdir, theBucketUUID];
    return [remoteFS contentsOfFileAtPath:path dataTransferDelegate:nil targetConnectionDelegate:theDelegate error:error];
}
- (BOOL)saveBucketPlistData:(NSData *)theData forComputerUUID:(NSString *)theComputerUUID bucketUUID:(NSString *)theBucketUUID deleted:(BOOL)deleted delegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    NSString *subdir = deleted ? @"deletedbuckets" : @"buckets";
    NSString *path = [NSString stringWithFormat:@"%@/%@/%@/%@", pathPrefix, theComputerUUID, subdir, theBucketUUID];
    return [remoteFS writeData:theData atomicallyToFileAtPath:path dataTransferDelegate:nil targetConnectionDelegate:theDelegate error:error];
}
- (BOOL)deleteBucketPlistDataForComputerUUID:(NSString *)theComputerUUID bucketUUID:(NSString *)theBucketUUID deleted:(BOOL)deleted delegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    NSString *subdir = deleted ? @"deletedbuckets" : @"buckets";
    NSString *path = [NSString stringWithFormat:@"%@/%@/%@/%@", pathPrefix, theComputerUUID, subdir, theBucketUUID];
    return [remoteFS removeItemAtPath:path targetConnectionDelegate:theDelegate error:error];
}

- (NSData *)computerInfoForComputerUUID:(NSString *)theComputerUUID delegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    NSString *path = [NSString stringWithFormat:@"%@/%@/computerinfo", pathPrefix, theComputerUUID];
    return [remoteFS contentsOfFileAtPath:path dataTransferDelegate:nil targetConnectionDelegate:theDelegate error:error];
}
- (BOOL)saveComputerInfo:(NSData *)theData forComputerUUID:(NSString *)theComputerUUID delegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    NSString *path = [NSString stringWithFormat:@"%@/%@/computerinfo", pathPrefix, theComputerUUID];
    return [remoteFS writeData:theData atomicallyToFileAtPath:path dataTransferDelegate:nil targetConnectionDelegate:theDelegate error:error];
}

- (NSArray *)objectsWithPrefix:(NSString *)thePrefix delegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    return [remoteFS objectsAtPath:thePrefix targetConnectionDelegate:theDelegate error:error];
}
- (NSArray *)pathsWithPrefix:(NSString *)thePrefix delegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    return [remoteFS pathsOfObjectsAtPath:thePrefix targetConnectionDelegate:theDelegate error:error];
}
- (BOOL)deleteObjectsForComputerUUID:(NSString *)theComputerUUID delegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    return [remoteFS removeItemAtPath:[NSString stringWithFormat:@"%@/%@", pathPrefix, theComputerUUID] targetConnectionDelegate:theDelegate error:error];
}
- (BOOL)deletePaths:(NSArray *)thePaths delegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    for (NSString *path in thePaths) {
        if (![remoteFS removeItemAtPath:path targetConnectionDelegate:theDelegate error:error]) {
            return NO;
        }
    }
    return YES;
}

- (NSNumber *)fileExistsAtPath:(NSString *)thePath dataSize:(unsigned long long *)theDataSize delegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    return [remoteFS fileExistsAtPath:thePath dataSize:theDataSize targetConnectionDelegate:theDelegate error:error];
}
- (NSData *)contentsOfFileAtPath:(NSString *)thePath delegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    return [remoteFS contentsOfFileAtPath:thePath dataTransferDelegate:nil targetConnectionDelegate:theDelegate error:error];
}
- (BOOL)writeData:(NSData *)theData toFileAtPath:(NSString *)thePath dataTransferDelegate:(id <DataTransferDelegate>)theDataTransferDelegate targetConnectionDelegate:(id <TargetConnectionDelegate>)theTargetConnectionDelegate error:(NSError **)error {
    return [remoteFS writeData:theData atomicallyToFileAtPath:thePath dataTransferDelegate:theDataTransferDelegate targetConnectionDelegate:theTargetConnectionDelegate error:error];
}
- (BOOL)removeItemAtPath:(NSString *)thePath delegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    return [remoteFS removeItemAtPath:thePath targetConnectionDelegate:theDelegate error:error];
}
- (NSNumber *)sizeOfItemAtPath:(NSString *)thePath delegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    return [remoteFS sizeOfItemAtPath:thePath targetConnectionDelegate:theDelegate error:error];
}
- (NSNumber *)isObjectRestoredAtPath:(NSString *)thePath delegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    return [remoteFS isObjectRestoredAtPath:thePath targetConnectionDelegate:theDelegate error:error];
}
- (BOOL)restoreObjectAtPath:(NSString *)thePath forDays:(NSUInteger)theDays alreadyRestoredOrRestoring:(BOOL *)alreadyRestoredOrRestoring delegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    return [remoteFS restoreObjectAtPath:thePath forDays:theDays alreadyRestoredOrRestoring:alreadyRestoredOrRestoring targetConnectionDelegate:theDelegate error:error];
}

- (NSData *)saltDataForComputerUUID:(NSString *)theComputerUUID delegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    NSString *s3Path = [NSString stringWithFormat:@"%@/%@/salt", pathPrefix, theComputerUUID];
    return [remoteFS contentsOfFileAtPath:s3Path dataTransferDelegate:nil targetConnectionDelegate:theDelegate error:error];
}
- (BOOL)setSaltData:(NSData *)theData forComputerUUID:(NSString *)theComputerUUID delegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    NSString *s3Path = [NSString stringWithFormat:@"%@/%@/salt", pathPrefix, theComputerUUID];
    return [remoteFS writeData:theData atomicallyToFileAtPath:s3Path dataTransferDelegate:nil targetConnectionDelegate:theDelegate error:error];
}
@end
