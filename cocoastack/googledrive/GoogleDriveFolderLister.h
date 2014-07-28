//
//  GoogleDriveFolderLister.h
//  Arq
//
//  Created by Stefan Reitshamer on 7/17/14.
//  Copyright (c) 2014 Stefan Reitshamer. All rights reserved.
//

@protocol GoogleDriveDelegate;
@protocol TargetConnectionDelegate;


@interface GoogleDriveFolderLister : NSObject {
    NSString *emailAddress;
    NSString *refreshToken;
    NSString *folderId;
    NSString *fileName;
    id <GoogleDriveDelegate> googleDriveDelegate;
    id <TargetConnectionDelegate> targetConnectionDelegate;
    NSString *pageToken;
}

- (id)initWithEmailAddress:(NSString *)theEmailAddress refreshToken:(NSString *)theRefreshToken folderId:(NSString *)theFolderId googleDriveDelegate:(id <GoogleDriveDelegate>)theDelegate targetConnectionDelegate:(id<TargetConnectionDelegate>)theDelegate;
- (id)initWithEmailAddress:(NSString *)theEmailAddress refreshToken:(NSString *)theRefreshToken folderId:(NSString *)theFolderId name:(NSString *)theName googleDriveDelegate:(id <GoogleDriveDelegate>)theDelegate targetConnectionDelegate:(id<TargetConnectionDelegate>)theDelegate;

// Return NSDictionaries of metadata as given by Google response JSON.
- (NSArray *)googleDriveItems:(NSError **)error;
@end
