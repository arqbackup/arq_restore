//
//  AppKeychain.h
//  Backup
//
//  Created by Stefan Reitshamer on 8/26/09.
//  Copyright 2009 PhotoMinds LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface AppKeychain : NSObject {
    NSString *backupAppPath;
    NSString *agentAppPath;
    SecAccessRef access;
}
+ (BOOL)accessKeyID:(NSString **)accessKeyID secretAccessKey:(NSString **)secret error:(NSError **)error;
+ (BOOL)containsEncryptionPasswordForS3BucketName:(NSString *)theS3BucketName computerUUID:(NSString *)theComputerUUID;
+ (BOOL)encryptionPassword:(NSString **)encryptionPassword forS3BucketName:(NSString *)theS3BucketName computerUUID:(NSString *)theComputerUUID error:(NSError **)error;
+ (BOOL)twitterAccessKey:(NSString **)theAccessKey secret:(NSString **)secret error:(NSError **)error;

- (id)initWithBackupAppPath:(NSString *)backupAppPath agentAppPath:(NSString *)agentAppPath;
- (BOOL)setAccessKeyID:(NSString *)theAccessKeyID secretAccessKey:(NSString *)theSecretAccessKey error:(NSError **)error;
- (BOOL)setEncryptionKey:(NSString *)theEncryptionPassword forS3BucketName:(NSString *)theS3BucketName computerUUID:(NSString *)theComputerUUID error:(NSError **)error;
- (BOOL)setTwitterAccessKey:(NSString *)theKey secret:(NSString *)theSecret error:(NSError **)error;
- (BOOL)deleteTwitterAccessKey:(NSError **)error;
@end
