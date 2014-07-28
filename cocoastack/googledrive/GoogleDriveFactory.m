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
