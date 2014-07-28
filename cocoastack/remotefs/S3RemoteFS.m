//
//  S3RemoteFS.m
//  Arq
//
//  Created by Stefan Reitshamer on 3/18/14.
//  Copyright (c) 2014 Stefan Reitshamer. All rights reserved.
//

#import "S3RemoteFS.h"
#import "Target.h"
#import "S3AuthorizationProvider.h"
#import "S3Service.h"
#import "NSString_extra.h"
#import "S3ObjectMetadata.h"


@implementation S3RemoteFS
- (id)initWithTarget:(Target *)theTarget {
    if (self = [super init]) {
        target = [theTarget retain];
    }
    return self;
}
- (void)dealloc {
    [target release];
    [s3 release];
    [super dealloc];
}


#pragma mark RemoteFS
- (NSString *)errorDomain {
    return @"RemoteFSErrorDomain";
}
- (NSNumber *)fileExistsAtPath:(NSString *)thePath isDirectory:(BOOL *)isDirectory targetConnectionDelegate:(id<TargetConnectionDelegate>)theTCD error:(NSError **)error {
    if (![self setUp:error]) {
        return nil;
    }
    thePath = [thePath stringByDeletingTrailingSlash];
    
    NSNumber *ret = [s3 containsObjectAtPath:thePath dataSize:NULL targetConnectionDelegate:theTCD error:error];
    if (ret == nil) {
        return nil;
    }
    if (isDirectory != NULL) {
        NSString *dir = [thePath stringByAppendingString:@"/"];
        NSArray *prefixes = [s3 commonPrefixesForPathPrefix:dir delimiter:@"/" targetConnectionDelegate:theTCD error:error];
        if (prefixes == nil) {
            return nil;
        }
        *isDirectory = [prefixes count] > 0; //FIXME: Does this work?! Never been tested!
    }
    return ret;
}
- (NSNumber *)fileExistsAtPath:(NSString *)thePath dataSize:(unsigned long long *)theDataSize targetConnectionDelegate:(id<TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    if (![self setUp:error]) {
        return nil;
    }
    return [s3 containsObjectAtPath:thePath dataSize:theDataSize targetConnectionDelegate:theDelegate error:error];
}
- (NSArray *)contentsOfDirectoryAtPath:(NSString *)thePath targetConnectionDelegate:(id<TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    if (![self setUp:error]) {
        return nil;
    }
    if (![thePath hasSuffix:@"/"]) {
        thePath = [thePath stringByAppendingString:@"/"];
    }
    return [s3 commonPrefixesForPathPrefix:thePath delimiter:@"/" targetConnectionDelegate:theDelegate error:error];
}
- (NSData *)contentsOfFileAtPath:(NSString *)thePath dataTransferDelegate:(id<DataTransferDelegate>)theDTDelegate targetConnectionDelegate:(id<TargetConnectionDelegate>)theTCDelegate error:(NSError **)error {
    if (![self setUp:error]) {
        return nil;
    }
    return [s3 dataAtPath:thePath dataTransferDelegate:theDTDelegate targetConnectionDelegate:theTCDelegate error:error];
}
- (BOOL)writeData:(NSData *)theData atomicallyToFileAtPath:(NSString *)thePath dataTransferDelegate:(id<DataTransferDelegate>)theDTDelegate targetConnectionDelegate:(id<TargetConnectionDelegate>)theTCDelegate error:(NSError **)error {
    if (![self setUp:error]) {
        return NO;
    }
    return [s3 putData:theData atPath:thePath dataTransferDelegate:theDTDelegate targetConnectionDelegate:theTCDelegate error:error];
}
- (BOOL)removeItemAtPath:(NSString *)thePath targetConnectionDelegate:(id<TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    if (![self setUp:error]) {
        return NO;
    }
    return [s3 deletePath:thePath targetConnectionDelegate:theDelegate error:error];
}
- (BOOL)createDirectoryAtPath:(NSString *)path withIntermediateDirectories:(BOOL)createIntermediates targetConnectionDelegate:(id<TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    return YES;
}
- (NSNumber *)sizeOfItemAtPath:(NSString *)thePath targetConnectionDelegate:(id<TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    if (![self setUp:error]) {
        return nil;
    }
    NSArray *objects = [s3 objectsWithPrefix:thePath targetConnectionDelegate:theDelegate error:error];
    if (objects == nil) {
        return nil;
    }
    unsigned long long total = 0;
    for (S3ObjectMetadata *md in objects) {
        total += [md size];
    }
    return [NSNumber numberWithUnsignedLongLong:total];
}
- (NSArray *)objectsAtPath:(NSString *)thePath targetConnectionDelegate:(id<TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    if (![self setUp:error]) {
        return nil;
    }
    return [s3 objectsWithPrefix:thePath targetConnectionDelegate:theDelegate error:error];
}
- (NSArray *)pathsOfObjectsAtPath:(NSString *)thePath targetConnectionDelegate:(id<TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    if (![self setUp:error]) {
        return nil;
    }
    return [s3 pathsWithPrefix:thePath delimiter:nil targetConnectionDelegate:theDelegate error:error];
}
- (NSNumber *)isObjectRestoredAtPath:(NSString *)thePath targetConnectionDelegate:(id<TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    if (![self setUp:error]) {
        return nil;
    }
    return [s3 isObjectRestoredAtPath:thePath targetConnectionDelegate:theDelegate error:error];
}
- (BOOL)restoreObjectAtPath:(NSString *)thePath forDays:(NSUInteger)theDays alreadyRestoredOrRestoring:(BOOL *)alreadyRestoredOrRestoring targetConnectionDelegate:(id<TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    if (![self setUp:error]) {
        return nil;
    }
    return [s3 restoreObjectAtPath:thePath forDays:theDays alreadyRestoredOrRestoring:alreadyRestoredOrRestoring targetConnectionDelegate:theDelegate error:error];
}


#pragma mark internal
- (BOOL)setUp:(NSError **)error {
    if (s3 == nil) {
        NSString *secret = [target secret:error];
        if (secret == nil) {
            return NO;
        }
        S3AuthorizationProvider *sap = [[[S3AuthorizationProvider alloc] initWithAccessKey:[[target endpoint] user] secretKey:secret] autorelease];
        NSString *portString = @"";
        if ([[[target endpoint] port] intValue] != 0) {
            portString = [NSString stringWithFormat:@":%d", [[[target endpoint] port] intValue]];
        }
        NSURL *s3Endpoint = [NSURL URLWithString:[NSString stringWithFormat:@"%@://%@%@", [[target endpoint] scheme], [[target endpoint] host], portString]];
        s3 = [[S3Service alloc] initWithS3AuthorizationProvider:sap endpoint:s3Endpoint useAmazonRRS:NO];
    }
    return YES;
}
@end
