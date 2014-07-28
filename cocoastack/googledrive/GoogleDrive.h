//
//  GoogleDrive.h
//  Arq
//
//  Created by Stefan Reitshamer on 7/16/14.
//  Copyright (c) 2014 Stefan Reitshamer. All rights reserved.
//

@protocol TargetConnectionDelegate;
@class Target;
@class GoogleDrive;
@protocol DataTransferDelegate;


@protocol GoogleDriveDelegate <NSObject>
- (NSString *)googleDriveAccessTokenForRefreshToken:(NSString *)theRefreshToken;
- (void)googleDriveDidChangeAccessToken:(NSString *)theUpdatedAccessToken forRefreshToken:(NSString *)theRefreshToken;
- (void)googleDriveDidFindFolderId:(NSString *)theFolderId forPath:(NSString *)thePath refreshToken:(NSString *)theRefreshToken;;
- (NSString *)googleDriveFolderIdForPath:(NSString *)thePath refreshToken:(NSString *)theRefreshToken;;;
@end


@interface GoogleDrive : NSObject {
    NSString *emailAddress;
    NSString *refreshToken;
    id <GoogleDriveDelegate> delegate;
}

+ (NSString *)errorDomain;
+ (NSURL *)endpoint;

- (id)initWithEmailAddress:(NSString *)theEmailAddress refreshToken:(NSString *)theRefreshToken delegate:(id <GoogleDriveDelegate>)theDelegate;

- (NSDictionary *)aboutWithTargetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD error:(NSError **)error;
- (NSNumber *)fileExistsAtPath:(NSString *)thePath isDirectory:(BOOL *)isDirectory targetConnectionDelegate:(id<TargetConnectionDelegate>)theDelegate error:(NSError **)error;
- (NSNumber *)fileExistsAtPath:(NSString *)thePath dataSize:(unsigned long long *)theDataSize targetConnectionDelegate:(id<TargetConnectionDelegate>)theDelegate error:(NSError **)error;

- (NSArray *)contentsOfDirectoryAtPath:(NSString *)thePath targetConnectionDelegate:(id<TargetConnectionDelegate>)theDelegate error:(NSError **)error;
- (BOOL)createDirectoryAtPath:(NSString *)path withIntermediateDirectories:(BOOL)createIntermediates targetConnectionDelegate:(id<TargetConnectionDelegate>)theDelegate error:(NSError **)error;
- (BOOL)removeItemAtPath:(NSString *)thePath targetConnectionDelegate:(id<TargetConnectionDelegate>)theDelegate error:(NSError **)error;

- (NSData *)contentsOfFileAtPath:(NSString *)thePath dataTransferDelegate:(id<DataTransferDelegate>)theDTDelegate targetConnectionDelegate:(id<TargetConnectionDelegate>)theTCDelegate error:(NSError **)error;
- (BOOL)writeData:(NSData *)theData mimeType:(NSString *)theMimeType toFileAtPath:(NSString *)thePath dataTransferDelegate:(id <DataTransferDelegate>)theDelegate targetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD error:(NSError **)error;

- (NSNumber *)sizeOfItemAtPath:(NSString *)thePath targetConnectionDelegate:(id<TargetConnectionDelegate>)theDelegate error:(NSError **)error;

- (NSArray *)objectsAtPath:(NSString *)thePath targetConnectionDelegate:(id<TargetConnectionDelegate>)theDelegate error:(NSError **)error;
- (NSArray *)pathsOfObjectsAtPath:(NSString *)thePath targetConnectionDelegate:(id<TargetConnectionDelegate>)theDelegate error:(NSError **)error;

@end
