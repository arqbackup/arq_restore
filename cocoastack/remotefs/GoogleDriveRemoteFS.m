//
//  GoogleDriveRemoteFS.m
//  Arq
//
//  Created by Stefan Reitshamer on 7/16/14.
//  Copyright (c) 2014 Stefan Reitshamer. All rights reserved.
//

#import "GoogleDriveRemoteFS.h"
#import "NSString_extra.h"
#import "Target.h"
#import "GoogleDrive.h"
#import "GoogleDriveFactory.h"


@implementation GoogleDriveRemoteFS

- (id)initWithTarget:(Target *)theTarget {
    if (self = [super init]) {
        target = [theTarget retain];
    }
    return self;
}
- (void)dealloc {
    [target release];
    [googleDrive release];
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
    
    NSNumber *ret = [googleDrive fileExistsAtPath:thePath isDirectory:isDirectory targetConnectionDelegate:theTCD error:error];
    if (ret == nil) {
        return nil;
    }
    return ret;
}
- (NSNumber *)fileExistsAtPath:(NSString *)thePath dataSize:(unsigned long long *)theDataSize targetConnectionDelegate:(id<TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    if (![self setUp:error]) {
        return nil;
    }
    return [googleDrive fileExistsAtPath:thePath dataSize:theDataSize targetConnectionDelegate:theDelegate error:error];
}
- (NSArray *)contentsOfDirectoryAtPath:(NSString *)thePath targetConnectionDelegate:(id<TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    if (![self setUp:error]) {
        return nil;
    }
    return [googleDrive contentsOfDirectoryAtPath:thePath targetConnectionDelegate:theDelegate error:error];
}
- (NSData *)contentsOfFileAtPath:(NSString *)thePath dataTransferDelegate:(id<DataTransferDelegate>)theDTDelegate targetConnectionDelegate:(id<TargetConnectionDelegate>)theTCDelegate error:(NSError **)error {
    if (![self setUp:error]) {
        return nil;
    }
    return [googleDrive contentsOfFileAtPath:thePath dataTransferDelegate:theDTDelegate targetConnectionDelegate:theTCDelegate error:error];
}
- (BOOL)writeData:(NSData *)theData atomicallyToFileAtPath:(NSString *)thePath dataTransferDelegate:(id<DataTransferDelegate>)theDTDelegate targetConnectionDelegate:(id<TargetConnectionDelegate>)theTCDelegate error:(NSError **)error {
    if (![self setUp:error]) {
        return NO;
    }
    return [googleDrive writeData:theData mimeType:@"binary/octet-stream" toFileAtPath:thePath dataTransferDelegate:theDTDelegate targetConnectionDelegate:theTCDelegate error:error];
}
- (BOOL)removeItemAtPath:(NSString *)thePath targetConnectionDelegate:(id<TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    if (![self setUp:error]) {
        return NO;
    }
    return [googleDrive removeItemAtPath:thePath targetConnectionDelegate:theDelegate error:error];
}
- (BOOL)createDirectoryAtPath:(NSString *)path withIntermediateDirectories:(BOOL)createIntermediates targetConnectionDelegate:(id<TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    return [googleDrive createDirectoryAtPath:path withIntermediateDirectories:createIntermediates targetConnectionDelegate:theDelegate error:error];
}
- (NSNumber *)sizeOfItemAtPath:(NSString *)thePath targetConnectionDelegate:(id<TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    if (![self setUp:error]) {
        return nil;
    }
    return [googleDrive sizeOfItemAtPath:thePath targetConnectionDelegate:theDelegate error:error];
    return nil;
}

// Returns an NSArray of S3ObjectMetadata objects.
- (NSArray *)objectsAtPath:(NSString *)thePath targetConnectionDelegate:(id<TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    if (![self setUp:error]) {
        return nil;
    }
    return [googleDrive objectsAtPath:thePath targetConnectionDelegate:theDelegate error:error];
    return nil;
}
- (NSArray *)pathsOfObjectsAtPath:(NSString *)thePath targetConnectionDelegate:(id<TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    if (![self setUp:error]) {
        return nil;
    }
    return [googleDrive pathsOfObjectsAtPath:thePath targetConnectionDelegate:theDelegate error:error];
    return nil;
}
- (NSNumber *)isObjectRestoredAtPath:(NSString *)thePath targetConnectionDelegate:(id <TargetConnectionDelegate>)theTargetConnectionDelegate error:(NSError **)error {
    SETNSERROR([self errorDomain], -1, @"isObjectRestoredAtPath is not supported by GoogleDriveRemoteFS");
    return nil;
}
- (BOOL)restoreObjectAtPath:(NSString *)thePath forDays:(NSUInteger)theDays alreadyRestoredOrRestoring:(BOOL *)alreadyRestoredOrRestoring targetConnectionDelegate:(id <TargetConnectionDelegate>)theTargetConnectionDelegate error:(NSError **)error {
    SETNSERROR([self errorDomain], -1, @"restoreObjectAtPath is not supported by GoogleDriveRemoteFS");
    return NO;
}


#pragma mark internal
- (BOOL)setUp:(NSError **)error {
    if (googleDrive == nil) {
        NSString *secret = [target secret:error];
        if (secret == nil) {
            return NO;
        }
        googleDrive = [[[GoogleDriveFactory sharedGoogleDriveFactory] googleDriveWithEmailAddress:[[target endpoint] user] refreshToken:secret] retain];
    }
    return YES;
}

@end
