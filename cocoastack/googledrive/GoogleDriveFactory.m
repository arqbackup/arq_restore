//
//  GoogleDriveFactory.m
//  Arq
//
//  Created by Stefan Reitshamer on 7/17/14.
//  Copyright (c) 2014 Stefan Reitshamer. All rights reserved.
//

#import "GoogleDriveFactory.h"


@implementation GoogleDriveFactory
CWL_SYNTHESIZE_SINGLETON_FOR_CLASS(GoogleDriveFactory)

- (id)init {
    if (self = [super init]) {
        accessTokensByRefreshToken = [[NSMutableDictionary alloc] init];
        folderIdDictionariesByRefreshToken = [[NSMutableDictionary alloc] init];
//        [folderIdsByPath setObject:@"root" forKey:@"/"];
        lock = [[NSLock alloc] init];
        [lock setName:@"GoogleDriveFactory lock"];
    }
    return self;
}
- (void)dealloc {
    [accessTokensByRefreshToken release];
    [folderIdDictionariesByRefreshToken release];
    [lock release];
    [super dealloc];
}


- (GoogleDrive *)googleDriveWithEmailAddress:(NSString *)theEmailAddress refreshToken:(NSString *)theRefreshToken {
    return [[[GoogleDrive alloc] initWithEmailAddress:theEmailAddress refreshToken:theRefreshToken delegate:self] autorelease];
}


#pragma mark GoogleDriveDelegate
- (NSString *)googleDriveAccessTokenForRefreshToken:(NSString *)theRefreshToken {
    [lock lock];
    NSString *ret = [[[accessTokensByRefreshToken objectForKey:theRefreshToken] copy] autorelease];
    [lock unlock];
    return ret;
}
- (void)googleDriveDidChangeAccessToken:(NSString *)theUpdatedAccessToken forRefreshToken:(NSString *)theRefreshToken {
    [lock lock];
    if (theUpdatedAccessToken == nil) {
        [accessTokensByRefreshToken removeObjectForKey:theRefreshToken];
    } else {
        [accessTokensByRefreshToken setObject:theUpdatedAccessToken forKey:theRefreshToken];
    }
    [lock unlock];
}
- (void)googleDriveDidFindFolderId:(NSString *)theFolderId forPath:(NSString *)thePath refreshToken:(NSString *)theRefreshToken {
    [lock lock];
    NSMutableDictionary *folderIdsByPath = [folderIdDictionariesByRefreshToken objectForKey:theRefreshToken];
    if (folderIdsByPath == nil) {
        folderIdsByPath = [NSMutableDictionary dictionaryWithObject:@"root" forKey:@"/"];
        [folderIdDictionariesByRefreshToken setObject:folderIdsByPath forKey:theRefreshToken];
    }
    [folderIdsByPath setObject:theFolderId forKey:thePath];
    [lock unlock];
}
- (NSString *)googleDriveFolderIdForPath:(NSString *)thePath refreshToken:(NSString *)theRefreshToken {
    [lock lock];
    NSMutableDictionary *folderIdsByPath = [folderIdDictionariesByRefreshToken objectForKey:theRefreshToken];
    if (folderIdsByPath == nil) {
        folderIdsByPath = [NSMutableDictionary dictionaryWithObject:@"root" forKey:@"/"];
        [folderIdDictionariesByRefreshToken setObject:folderIdsByPath forKey:theRefreshToken];
    }
    NSString *ret = [[[folderIdsByPath objectForKey:thePath] copy] autorelease];
    [lock unlock];
    return ret;
}
@end
