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
