//
//  SFTPServer.h
//  Arq
//
//  Created by Stefan Reitshamer on 1/31/14.
//  Copyright (c) 2014 Stefan Reitshamer. All rights reserved.
//

#include "libssh2.h"
#include "libssh2_sftp.h"
@protocol DataTransferDelegate;


@interface SFTPServer : NSObject {
    NSDate *dateCreated;
    BOOL errorOccurred;
    int port;
    NSString *username;
    NSString *password;
    NSString *privateKeyPath;
    NSString *passphrase;
    NSString *hostname;
    int sock;
    LIBSSH2_SESSION *session;
    LIBSSH2_SFTP *sftp;
}

- (id)initWithURL:(NSURL *)theURL
         password:(NSString *)thePassword
   privateKeyPath:(NSString *)thePrivateKeyPath
       passphrase:(NSString *)thePassphrase
            error:(NSError **)error;

- (NSString *)errorDomain;
- (NSDate *)dateCreated;
- (BOOL)errorOccurred;

- (NSString *)realPathForPath:(NSString *)thePath error:(NSError **)error;
- (NSNumber *)fileExistsAtPath:(NSString *)thePath isDirectory:(BOOL *)isDirectory error:(NSError **)error;
- (NSNumber *)fileExistsAtPath:(NSString *)thePath dataSize:(unsigned long long *)theDataSize error:(NSError **)error;
- (NSArray *)contentsOfDirectoryAtPath:(NSString *)thePath error:(NSError **)error;
- (NSData *)contentsOfFileAtPath:(NSString *)thePath dataTransferDelegate:(id <DataTransferDelegate>)theDelegate error:(NSError **)error;
- (BOOL)writeData:(NSData *)theData toFileAtPath:(NSString *)thePath dataTransferDelegate:(id <DataTransferDelegate>)theDelegate error:(NSError **)error;
- (BOOL)renameItemAtPath:(NSString *)theFromPath toPath:(NSString *)theToPath error:(NSError **)error;
- (BOOL)removeItemAtPath:(NSString *)thePath error:(NSError **)error;
- (BOOL)createDirectoryAtPath:(NSString *)path withIntermediateDirectories:(BOOL)createIntermediates error:(NSError **)error;
- (BOOL)ensureParentPathExistsForPath:(NSString *)thePath error:(NSError **)error;
- (NSNumber *)sizeOfItemAtPath:(NSString *)thePath error:(NSError **)error;
- (NSArray *)objectsAtPath:(NSString *)thePath error:(NSError **)error;
- (NSArray *)pathsOfObjectsAtPath:(NSString *)thePath error:(NSError **)error;

@end
