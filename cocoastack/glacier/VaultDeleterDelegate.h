//
//  VaultDeleterDelegate.h
//  Arq
//
//  Created by Stefan Reitshamer on 12/1/12.
//  Copyright (c) 2012 Stefan Reitshamer. All rights reserved.
//



@protocol VaultDeleterDelegate <NSObject>
- (void)vaultDeleterStatusDidChange:(NSString *)theMessage;
- (BOOL)vaultDeleterAbortRequestedForVaultName:(NSString *)theVaultName;
- (void)vaultDeleterDidRetrieveArchiveCount:(NSUInteger)theCount;
- (void)vaultDeleterDidDeleteArchive;
@end
