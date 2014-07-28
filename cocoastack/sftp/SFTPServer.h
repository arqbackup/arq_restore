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
