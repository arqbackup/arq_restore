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

#import "PackSetSet.h"
#import "PackSet.h"
#import "SetNSError.h"
#import "NSErrorCodes.h"
#import "S3Service.h"
#import "ArqUserLibrary.h"
#import "RegexKitLite.h"

@interface PackSetSet (internal)
- (NSDictionary *)packSHA1sByPackSetNameFromS3:(NSError **)error;
- (NSMutableSet *)diskPackSetNames:(NSError **)error;
- (PackSet *)packSetForName:(NSString *)packSetName error:(NSError **)error;
- (NSArray *)cachedPackSHA1sForPackSet:(NSString *)packSetName error:(NSError **)error;
@end

@implementation PackSetSet
+ (NSString *)s3PathWithS3BucketName:(NSString *)theS3BucketName computerUUID:(NSString *)theComputerUUID {
    return [NSString stringWithFormat:@"/%@/%@/packsets", theS3BucketName, theComputerUUID];
}
+ (NSString *)localPathWithComputerUUID:(NSString *)computerUUID {
    return [NSString stringWithFormat:@"%@/%@/packsets", [ArqUserLibrary arqCachesPath], computerUUID];
}

- (id)initWithS3Service:(S3Service *)theS3
           s3BucketName:(NSString *)theS3BucketName
           computerUUID:(NSString *)theComputerUUID {
    if (self = [super init]) {
        s3 = [theS3 retain];
        s3BucketName = [theS3BucketName copy];
        computerUUID = [theComputerUUID copy];
        packSets = [[NSMutableDictionary alloc] init];
    }
    return self;
}
- (void)dealloc {
    [s3 release];
    [s3BucketName release];
    [computerUUID release];
    [packSets release];
    [super dealloc];
}
- (ServerBlob *)newServerBlobForSHA1:(NSString *)sha1 packSetName:(NSString *)packSetName error:(NSError **)error {
    PackSet *packSet = [self packSetForName:packSetName error:error];
    if (packSet == nil) {
        return nil;
    }
    return [packSet newServerBlobForSHA1:sha1 error:error];
}
- (BOOL)containsBlobForSHA1:(NSString *)sha1 packSetName:(NSString *)packSetName {
    BOOL contains = [[packSets objectForKey:packSetName] containsBlobForSHA1:sha1];
    return contains;
}
- (NSString *)packSHA1ForPackedBlobSHA1:(NSString *)sha1 packSetName:(NSString *)packSetName {
	NSError *myError = nil;
    PackSet *packSet = [self packSetForName:packSetName error:&myError];
    if (packSet == nil) {
		HSLogError(@"%@", [myError localizedDescription]);
        return nil;
    }
	return [packSet packSHA1ForPackedBlobSHA1:sha1];
}
- (NSArray *)resetFromS3:(NSError **)error {
    HSLogDebug(@"resetting pack sets from S3");
    [packSets removeAllObjects];
    NSDictionary *s3PackSHA1sByPackSetName = [self packSHA1sByPackSetNameFromS3:error];
    if (s3PackSHA1sByPackSetName == nil) {
        return nil;
    }
    
    //
    // Remove disk pack sets that don't exist in S3.
    //
    NSMutableSet *diskPackSetNames = [self diskPackSetNames:error];
    if (diskPackSetNames == nil) {
        return nil;
    }
    NSMutableSet *s3PackSetNames = [NSMutableSet setWithArray:[s3PackSHA1sByPackSetName allKeys]];
    [diskPackSetNames minusSet:s3PackSetNames];
    for (NSString *bogusDiskPackSetName in diskPackSetNames) {
        NSString *packSetPath = [PackSet localPathWithComputerUUID:computerUUID packSetName:bogusDiskPackSetName];
        HSLogDebug(@"removing local pack set that doesn't exist in S3: %@", packSetPath);
        if (![[NSFileManager defaultManager] removeItemAtPath:packSetPath error:error]) {
            return nil;
        }
    }
    
    //
    // Create PackSets, make index files local, and load PackIndexEntries into memory.
    //
    for (NSString *s3PackSetName in [s3PackSHA1sByPackSetName allKeys]) {
        NSArray *packSHA1s = [s3PackSHA1sByPackSetName objectForKey:s3PackSetName];
        PackSet *packSet = [[[PackSet alloc] initWithName:s3PackSetName 
                                                s3Service:s3 
                                             s3BucketName:s3BucketName 
                                             computerUUID:computerUUID 
                                           keepPacksLocal:[s3PackSetName hasSuffix:@"-trees"] 
                                                packSHA1s:packSHA1s error:error] autorelease];
        if (packSet == nil) {
            return nil;
        }
        [packSets setObject:packSet forKey:s3PackSetName];
    }
	NSMutableArray *ret = [NSMutableArray array];
	for (NSArray *sha1s in [s3PackSHA1sByPackSetName allValues]) {
		[ret addObjectsFromArray:sha1s];
	}
	return ret;
}
@end
@implementation PackSetSet (internal)
- (NSDictionary *)packSHA1sByPackSetNameFromS3:(NSError **)error {
    NSMutableDictionary *packSHA1sByPackSetName = [NSMutableDictionary dictionary];
    NSString *packSetPrefix = [PackSet s3PathWithS3BucketName:s3BucketName computerUUID:computerUUID packSetName:@""];
    NSArray *s3Paths = [s3 pathsWithPrefix:packSetPrefix error:error];
    if (s3Paths == nil) {
        return nil;
    }
    // Format: /<s3bucketname>/<computeruuid>/packsets/<packsetname>/<sha1>.pack
    NSString *pattern = [NSString stringWithFormat:@"^%@([^/]+)/(.+)\\.pack$", packSetPrefix];
    for (NSString *s3Path in s3Paths) {
        NSRange packSetNameRange = [s3Path rangeOfRegex:pattern capture:1];
        NSRange sha1Range = [s3Path rangeOfRegex:pattern capture:2];
        if (packSetNameRange.location != NSNotFound && sha1Range.location != NSNotFound) {
            NSString *escapedPackSetName = [s3Path substringWithRange:packSetNameRange];
            NSString *packSetName = [escapedPackSetName stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
            NSString *packSHA1 = [s3Path substringWithRange:sha1Range];
            NSMutableArray *packSHA1s = [packSHA1sByPackSetName objectForKey:packSetName];
            if (packSHA1s == nil) {
                packSHA1s = [NSMutableArray array];
                [packSHA1sByPackSetName setObject:packSHA1s forKey:packSetName];
            }
            [packSHA1s addObject:packSHA1];
        }
    }
    return packSHA1sByPackSetName;
}
- (NSMutableSet *)diskPackSetNames:(NSError **)error {
    NSMutableSet *diskPackSetNames = [NSMutableSet set];
    NSString *packSetsDir = [PackSetSet localPathWithComputerUUID:computerUUID];
    if ([[NSFileManager defaultManager] fileExistsAtPath:packSetsDir]) {
        NSArray *packSetNames = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:packSetsDir error:error];
        if (packSetNames == nil) {
            return nil;
        }
        for (NSString *packSetName in packSetNames) {
            if (![packSetName hasPrefix:@"."]) {
                [diskPackSetNames addObject:packSetName];
            }
        }
    }
    return diskPackSetNames;
}
- (PackSet *)packSetForName:(NSString *)packSetName error:(NSError **)error {
    PackSet *packSet = [packSets objectForKey:packSetName];
    if (packSet == nil) {
        NSError *myError;
        NSArray *packSHA1s = [self cachedPackSHA1sForPackSet:packSetName error:&myError];
        if (packSHA1s == nil) {
            HSLogError(@"error reading cached pack sets: %@", [myError localizedDescription]);
            packSHA1s = [NSArray array];
        }
        packSet = [[PackSet alloc] initWithName:packSetName 
                                      s3Service:s3 
                                   s3BucketName:s3BucketName 
                                   computerUUID:computerUUID 
                                 keepPacksLocal:[packSetName hasSuffix:@"-trees"] 
                                      packSHA1s:packSHA1s
                                          error:error];
        if (packSet == nil) {
            return nil;
        }
        [packSets setObject:packSet forKey:packSetName];
        [packSet release];
    }
    return packSet;
}
- (NSArray *)cachedPackSHA1sForPackSet:(NSString *)packSetName error:(NSError **)error {
    NSString *packSetDir = [PackSet localPathWithComputerUUID:computerUUID packSetName:packSetName];
    NSMutableArray *ret = [NSMutableArray array];
    BOOL isDir = NO;
    if ([[NSFileManager defaultManager] fileExistsAtPath:packSetDir isDirectory:&isDir] && isDir) {
        NSArray *dirNames = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:packSetDir error:error];
        if (dirNames == nil) {
            return nil;
        }
        for (NSString *dirName in dirNames) {
            NSString *dir = [packSetDir stringByAppendingPathComponent:dirName];
            if ([[NSFileManager defaultManager] fileExistsAtPath:dir isDirectory:&isDir] && isDir) {
                NSArray *fileNames = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:dir error:error];
                if (fileNames == nil) {
                    return nil;
                }
                for (NSString *fileName in fileNames) {
                    NSRange sha1Range = [fileName rangeOfRegex:@"^(.+)\\.index$" capture:1];
                    if (sha1Range.location != NSNotFound) {
                        NSString *sha1 = [dirName stringByAppendingString:[fileName substringWithRange:sha1Range]];
                        [ret addObject:sha1];
                    }
                }
            }
        }
    }
    return ret;
}
@end
