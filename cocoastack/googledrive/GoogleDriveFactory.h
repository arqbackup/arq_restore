//
//  GoogleDriveFactory.h
//  Arq
//
//  Created by Stefan Reitshamer on 7/17/14.
//  Copyright (c) 2014 Stefan Reitshamer. All rights reserved.
//

#import "CWLSynthesizeSingleton.h"
#import "GoogleDrive.h"


@interface GoogleDriveFactory : NSObject <GoogleDriveDelegate> {
    NSMutableDictionary *accessTokensByRefreshToken;
    NSMutableDictionary *folderIdDictionariesByRefreshToken;
    NSLock *lock;
}

CWL_DECLARE_SINGLETON_FOR_CLASS(GoogleDriveFactory);


- (GoogleDrive *)googleDriveWithEmailAddress:(NSString *)theEmailAddress refreshToken:(NSString *)theRefreshToken;
@end
