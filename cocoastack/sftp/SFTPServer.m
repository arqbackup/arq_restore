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


#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wpointer-sign"
#pragma clang diagnostic ignored "-Wtautological-compare"
#pragma clang diagnostic ignored "-Wshorten-64-to-32"


#include <netinet/in.h>
#include <sys/socket.h>
#include <netdb.h>

#import "SFTPServer.h"
#import "S3ObjectMetadata.h"
#import "NSString_extra.h"
#import "DataTransferDelegate.h"
#import "NetMonitor.h"
#import "HTTPThrottle.h"


#define BUFLEN (32768)
#define SFTP_TIMEOUT_MILLISECONDS (30000)


@implementation SFTPServer
- (id)initWithURL:(NSURL *)theURL
         password:(NSString *)thePassword
   privateKeyPath:(NSString *)thePrivateKeyPath
       passphrase:(NSString *)thePassphrase
            error:(NSError **)error {
    if (self = [super init]) {
        dateCreated = [[NSDate alloc] init];
        port = [[theURL port] intValue];
        username = [[theURL user] retain];
        password = [thePassword retain];
        privateKeyPath = [thePrivateKeyPath retain];
        passphrase = [thePassphrase retain];
        hostname = [[theURL host] retain];
        sock = -1;
        
        HSLogDetail(@"%p: connecting SFTPServer %@:%d", self, hostname, port);

        NSSocketPort *socketPort = [[[NSSocketPort alloc] initRemoteWithTCPPort:port host:hostname] autorelease];
        if ([socketPort address] == nil) {
            // Return this error so that [NSError isTransientError] returns YES:
            SETNSERROR(@"UnixErrorDomain", EADDRNOTAVAIL, @"unable to resolve host %@", hostname);
            [self release];
            return nil;
        }
        const struct sockaddr *addr = [[socketPort address] bytes];
        sock = socket(addr->sa_family, SOCK_STREAM, 0);
        if (sock == -1) {
            int errnum = errno;
            SETNSERROR([self errorDomain], errnum, @"Failed to create socket: %s", strerror(errnum));
            [self release];
            return nil;
        }
        if (connect(sock, [[socketPort address] bytes], (socklen_t)[[socketPort address] length])) {
            int errnum = errno;
            SETNSERROR(@"UnixErrorDomain", errnum, @"Failed to connect to %@ at port %d: %s", hostname, port, strerror(errnum));
            [self release];
            return nil;
        }
        
        session = libssh2_session_init();
        if (session == NULL) {
            SETNSERROR([self errorDomain], -1, @"libssh2_session_init failed");
            [self release];
            return nil;
        }
        if (libssh2_session_startup(session, sock) < 0) {
            char *msg = NULL;
            int sessionError = libssh2_session_last_error(session, &msg, NULL, 0);
            NSError *myError = [NSError errorWithDomain:[self errorDomain] code:sessionError userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                                                       [NSNumber numberWithInt:sessionError], @"libssh2SessionError",
                                                                                                       [NSString stringWithFormat:@"libssh2_session_startup error: %s", msg], NSLocalizedDescriptionKey,
                                                                                                       nil]];
            SETERRORFROMMYERROR;
            [self release];
            return nil;
        }
        
        libssh2_session_set_blocking(session, 1);
        libssh2_session_set_timeout(session, SFTP_TIMEOUT_MILLISECONDS);
        
        if ([password length] > 0) {
            if (libssh2_userauth_password_ex(session, [username UTF8String], (int)strlen([username UTF8String]), [password UTF8String], (int)strlen([password UTF8String]), NULL)) {
                char *msg = NULL;
                int sessionError = libssh2_session_last_error(session, &msg, NULL, 0);
                HSLogError(@"libssh2_userauth_password_ex error %d: %s", sessionError, msg);
                NSError *myError = [NSError errorWithDomain:[self errorDomain] code:sessionError userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                                                           [NSNumber numberWithInt:sessionError], @"libssh2SessionError",
                                                                                                           [NSString stringWithFormat:@"SFTP: %s", msg], NSLocalizedDescriptionKey,
                                                                                                           nil]];
                SETERRORFROMMYERROR;
                [self release];
                return nil;
            }
        } else if ([privateKeyPath length] > 0) {
            if (libssh2_userauth_publickey_fromfile_ex(session, [username UTF8String], (int)strlen([username UTF8String]), NULL, [privateKeyPath fileSystemRepresentation], [passphrase UTF8String])) {
                char *msg = NULL;
                int sessionError = libssh2_session_last_error(session, &msg, NULL, 0);
                HSLogError(@"libssh2_userauth_publickey_fromfile_ex error %d: %s", sessionError, msg);
                NSError *myError = [NSError errorWithDomain:[self errorDomain] code:sessionError userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                                                           [NSNumber numberWithInt:sessionError], @"libssh2SessionError",
                                                                                                           [NSString stringWithFormat:@"SFTP: %s", msg], NSLocalizedDescriptionKey,
                                                                                                           nil]];
                SETERRORFROMMYERROR;
                [self release];
                return nil;
            }
        } else {
            SETNSERROR([self errorDomain], -1, @"SFTP: no password or private key path given");
            [self release];
            return nil;
        }
        
        sftp = libssh2_sftp_init(session);
        if (sftp == NULL) {
            SETNSERROR([self errorDomain], -1, @"sftp init failed");
            [self release];
            return nil;
        }
    }
    return self;
}
- (void)dealloc {
    if (sftp != NULL) {
        HSLogDetail(@"%p: disconnected from SFTP server %@:%d", self, hostname, port);
        if (libssh2_sftp_shutdown(sftp) < 0) {
            HSLogError(@"libssh2_sftp_shutdown failed");
        }
        sftp = NULL;
    }
    if (session != NULL) {
        libssh2_session_free(session);
        session = NULL;
    }
    if (sock != -1) {
        close(sock);
        sock = -1;
    }

    [dateCreated release];
    [username release];
    [password release];
    [privateKeyPath release];
    [passphrase release];
    [hostname release];
    [super dealloc];
}

- (NSString *)errorDomain {
    return @"SFTPServerErrorDomain";
}
- (NSDate *)dateCreated {
    return dateCreated;
}
- (BOOL)errorOccurred {
    return errorOccurred;
}

- (NSString *)realPathForPath:(NSString *)thePath error:(NSError **)error {
    thePath = [thePath stringByDeletingTrailingSlash];
    char target[65536];
    int len = libssh2_sftp_realpath(sftp, [thePath UTF8String], target, 65536);
    if (len < 0) {
        char *msg = NULL;
        int sessionError = libssh2_session_last_error(session, &msg, NULL, 0);
        if (sessionError == LIBSSH2_ERROR_SFTP_PROTOCOL) {
            unsigned long sftpError = libssh2_sftp_last_error(sftp);            
            NSError *myError = [NSError errorWithDomain:[self errorDomain] code:sftpError userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                                                    [NSNumber numberWithInt:sessionError], @"libssh2SessionError",
                                                                                                    [NSNumber numberWithInt:sftpError], @"libssh2SFTPError",
                                                                                                    [NSString stringWithFormat:@"sftp opendir(%@) error: %@", thePath, [self descriptionForSFTPStatusCode:sftpError]], NSLocalizedDescriptionKey,
                                                                                                    nil]];
            SETERRORFROMMYERROR;
        } else {
            NSError *myError = [NSError errorWithDomain:[self errorDomain] code:sessionError userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                                                       [NSNumber numberWithInt:sessionError], @"libssh2SessionError",
                                                                                                       [NSString stringWithFormat:@"sftp opendir(%@) error: %s", thePath, msg], NSLocalizedDescriptionKey,
                                                                                                       nil]];
            SETERRORFROMMYERROR;
        }
        return nil;
    }
    return [[[NSString alloc] initWithBytes:target length:len encoding:NSUTF8StringEncoding] autorelease];
}
- (NSNumber *)fileExistsAtPath:(NSString *)thePath isDirectory:(BOOL *)isDirectory error:(NSError **)error {
    thePath = [thePath stringByDeletingTrailingSlash];
    return [self fileExistsAtPath:thePath isDirectory:isDirectory dataSize:NULL lastModifiedDate:NULL error:error];
}
- (NSNumber *)fileExistsAtPath:(NSString *)thePath dataSize:(unsigned long long *)theDataSize error:(NSError **)error {
    thePath = [thePath stringByDeletingTrailingSlash];
    return [self fileExistsAtPath:thePath isDirectory:NULL dataSize:theDataSize lastModifiedDate:NULL error:error];
}

- (NSArray *)contentsOfDirectoryAtPath:(NSString *)thePath error:(NSError **)error {
    thePath = [thePath stringByDeletingTrailingSlash];

    HSLogDebug(@"libssh2_sftp_opendir(%@)", thePath);
    LIBSSH2_SFTP_HANDLE *handle = libssh2_sftp_opendir(sftp, (char *)[thePath UTF8String]);
    if (handle == NULL) {
        char *msg = NULL;
        int sessionError = libssh2_session_last_error(session, &msg, NULL, 0);
        if (sessionError == LIBSSH2_ERROR_SFTP_PROTOCOL) {
            unsigned long sftpError = libssh2_sftp_last_error(sftp);
            // SFTP servers can return access-denied if the parent directory doesn't exist:
            if (sftpError == LIBSSH2_FX_NO_SUCH_FILE || sftpError == LIBSSH2_FX_PERMISSION_DENIED) {
                return [NSArray array];
            }
            
            NSError *myError = [NSError errorWithDomain:[self errorDomain] code:sftpError userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                                                    [NSNumber numberWithInt:sessionError], @"libssh2SessionError",
                                                                                                    [NSNumber numberWithInt:sftpError], @"libssh2SFTPError",
                                                                                                    [NSString stringWithFormat:@"sftp opendir(%@) error: %@", thePath, [self descriptionForSFTPStatusCode:sftpError]], NSLocalizedDescriptionKey,
                                                                                                    nil]];
            SETERRORFROMMYERROR;
        } else {
            NSError *myError = [NSError errorWithDomain:[self errorDomain] code:sessionError userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                                                    [NSNumber numberWithInt:sessionError], @"libssh2SessionError",
                                                                                                    [NSString stringWithFormat:@"sftp opendir(%@) error: %s", thePath, msg], NSLocalizedDescriptionKey,
                                                                                                    nil]];
            SETERRORFROMMYERROR;
        }
        errorOccurred = YES;
        return nil;
    }
    
    NSMutableArray *contents = [NSMutableArray array];
    char buf[BUFLEN];
    for (;;) {
        LIBSSH2_SFTP_ATTRIBUTES attrs;
//        HSLogDebug(@"libssh2_sftp_readdir(%@)", thePath);
        int rc = libssh2_sftp_readdir(handle, buf, BUFLEN, &attrs);
        if (rc < 0) {
            char *msg = NULL;
            int sessionError = libssh2_session_last_error(session, &msg, NULL, 0);
            if (sessionError == LIBSSH2_ERROR_SFTP_PROTOCOL) {
                unsigned long sftpError = libssh2_sftp_last_error(sftp);
                NSError *myError = [NSError errorWithDomain:[self errorDomain] code:sftpError userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                                                        [NSNumber numberWithInt:sessionError], @"libssh2SessionError",
                                                                                                        [NSNumber numberWithInt:sftpError], @"libssh2SFTPError",
                                                                                                        [NSString stringWithFormat:@"sftp readdir(%@) error: %@", thePath, [self descriptionForSFTPStatusCode:sftpError]], NSLocalizedDescriptionKey,
                                                                                                        nil]];
                SETERRORFROMMYERROR;
            } else {
                NSError *myError = [NSError errorWithDomain:[self errorDomain] code:sessionError userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                                                           [NSNumber numberWithInt:sessionError], @"libssh2SessionError",
                                                                                                           [NSString stringWithFormat:@"sftp readdir(%@) error: %s", thePath, msg], NSLocalizedDescriptionKey,
                                                                                                           nil]];
                SETERRORFROMMYERROR;
            }
            errorOccurred = YES;
            contents = nil;
            break;
        } else if (rc > 0) {
            NSString *name = [[[NSString alloc] initWithBytes:buf length:rc encoding:NSUTF8StringEncoding] autorelease];
            if (![name isEqualToString:@"."] && ![name isEqualToString:@".."]) {
                [contents addObject:name];
            }
        } else {
            break;
        }
    }
    if (libssh2_sftp_closedir(handle) < 0) {
        errorOccurred = YES;
    }
    
    return contents;
}


- (NSData *)contentsOfFileAtPath:(NSString *)thePath dataTransferDelegate:(id <DataTransferDelegate>)theDelegate error:(NSError **)error {
    thePath = [thePath stringByDeletingTrailingSlash];
    HSLogDebug(@"libssh2_sftp_open_ex(%@) for reading", thePath);
    // Open the file with all permissions because some broken SFTP servers (e.g. SSH-2.0-mod_sftp/0.9.8) set the file's permissions
    // when we open it for *reading* (the permissions are only supposed to be used when creating a file!)
    LIBSSH2_SFTP_HANDLE *handle = libssh2_sftp_open_ex(sftp,
                                                       [thePath UTF8String],
                                                       strlen([thePath UTF8String]),
                                                       LIBSSH2_FXF_READ, LIBSSH2_SFTP_S_IRWXU|LIBSSH2_SFTP_S_IRWXG|LIBSSH2_SFTP_S_IRWXO, LIBSSH2_SFTP_OPENFILE);
    if (handle == NULL) {
        char *msg = NULL;
        int sessionError = libssh2_session_last_error(session, &msg, NULL, 0);
        if (sessionError == LIBSSH2_ERROR_SFTP_PROTOCOL) {
            unsigned long sftpError = libssh2_sftp_last_error(sftp);
            if (sftpError == LIBSSH2_FX_NO_SUCH_FILE || sftpError == LIBSSH2_FX_PERMISSION_DENIED) {
                SETNSERROR([self errorDomain], ERROR_NOT_FOUND, @"%@ not found", thePath);
                return nil;
            }
            
            NSError *myError = [NSError errorWithDomain:[self errorDomain] code:sftpError userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                                                    [NSNumber numberWithInt:sessionError], @"libssh2SessionError",
                                                                                                    [NSNumber numberWithInt:sftpError], @"libssh2SFTPError",
                                                                                                    [NSString stringWithFormat:@"sftp open(%@) for reading error: %@", thePath, [self descriptionForSFTPStatusCode:sftpError]], NSLocalizedDescriptionKey,
                                                                                                    nil]];
            SETERRORFROMMYERROR;
        } else {
            NSError *myError = [NSError errorWithDomain:[self errorDomain] code:sessionError userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                                                       [NSNumber numberWithInt:sessionError], @"libssh2SessionError",
                                                                                                       [NSString stringWithFormat:@"sftp open(%@) for reading error: %s", thePath, msg], NSLocalizedDescriptionKey,
                                                                                                       nil]];
            SETERRORFROMMYERROR;
        }
        errorOccurred = YES;
        return nil;
    }
    
    NSMutableData *data = [NSMutableData data];
    ssize_t recvd;
    char buf[BUFLEN];
    for (;;) {
        recvd = libssh2_sftp_read(handle, buf, BUFLEN);
        if (recvd == 0) {
            break;
        } else if (recvd > 0) {
            [data appendBytes:buf length:recvd];
        } else {
            char *msg = NULL;
            int sessionError = libssh2_session_last_error(session, &msg, NULL, 0);
            if (sessionError == LIBSSH2_ERROR_SFTP_PROTOCOL) {
                unsigned long sftpError = libssh2_sftp_last_error(sftp);
                NSError *myError = [NSError errorWithDomain:[self errorDomain] code:sftpError userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                                                        [NSNumber numberWithInt:sessionError], @"libssh2SessionError",
                                                                                                        [NSNumber numberWithInt:sftpError], @"libssh2SFTPError",
                                                                                                        [NSString stringWithFormat:@"sftp read(%@) error: %@", thePath, [self descriptionForSFTPStatusCode:sftpError]], NSLocalizedDescriptionKey,
                                                                                                        nil]];
                SETERRORFROMMYERROR;
            } else {
                NSError *myError = [NSError errorWithDomain:[self errorDomain] code:sessionError userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                                                           [NSNumber numberWithInt:sessionError], @"libssh2SessionError",
                                                                                                           [NSString stringWithFormat:@"sftp read(%@) error: %s", thePath, msg], NSLocalizedDescriptionKey,
                                                                                                           nil]];
                SETERRORFROMMYERROR;
            }

            errorOccurred = YES;
            data = nil;
            break;
        }

        HTTPThrottle *httpThrottle = nil;
        if (theDelegate != nil && ![theDelegate dataTransferDidDownloadBytes:recvd httpThrottle:&httpThrottle error:error]) {
            errorOccurred = YES;
            data = nil;
            break;
        }
        //FIXME: Use the throttle!
    }
    if (libssh2_sftp_close(handle) < 0) {
        errorOccurred = YES;
    }
    return data;
}

- (BOOL)writeData:(NSData *)theData toFileAtPath:(NSString *)thePath dataTransferDelegate:(id <DataTransferDelegate>)theDelegate error:(NSError **)error {
    thePath = [thePath stringByDeletingTrailingSlash];
    if (![self doWriteData:theData toFileAtPath:thePath dataTransferDelegate:(id <DataTransferDelegate>)theDelegate error:NULL]) {
        if (![self ensureParentPathExistsForPath:thePath error:error]) {
            return NO;
        }
        if (![self doWriteData:theData toFileAtPath:thePath dataTransferDelegate:(id <DataTransferDelegate>)theDelegate error:error]) {
            return NO;
        }
    }
    return YES;
}


- (BOOL)renameItemAtPath:(NSString *)theFromPath toPath:(NSString *)theToPath error:(NSError **)error {
    HSLogDebug(@"libssh2_sftp_rename_ex(%@, %@)", theFromPath, theToPath);
    if (libssh2_sftp_rename(sftp, (const char *)[theFromPath UTF8String], (const char *)[theToPath UTF8String]) < 0) {
        char *msg = NULL;
        int sessionError = libssh2_session_last_error(session, &msg, NULL, 0);
        if (sessionError == LIBSSH2_ERROR_SFTP_PROTOCOL) {
            unsigned long sftpError = libssh2_sftp_last_error(sftp);
            NSError *myError = [NSError errorWithDomain:[self errorDomain] code:sftpError userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                                                    [NSNumber numberWithInt:sessionError], @"libssh2SessionError",
                                                                                                    [NSNumber numberWithInt:sftpError], @"libssh2SFTPError",
                                                                                                    [NSString stringWithFormat:@"sftp rename(%@, %@) error: %@", theFromPath, theToPath, [self descriptionForSFTPStatusCode:sftpError]], NSLocalizedDescriptionKey,
                                                                                                    nil]];
            SETERRORFROMMYERROR;
        } else {
            NSError *myError = [NSError errorWithDomain:[self errorDomain] code:sessionError userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                                                       [NSNumber numberWithInt:sessionError], @"libssh2SessionError",
                                                                                                       [NSString stringWithFormat:@"sftp rename(%@, %@) error: %s", theFromPath, theToPath, msg], NSLocalizedDescriptionKey,
                                                                                                       nil]];
            SETERRORFROMMYERROR;
        }
        errorOccurred = YES;
        return NO;
    }
    return YES;
}


- (BOOL)removeItemAtPath:(NSString *)thePath error:(NSError **)error {
    thePath = [thePath stringByDeletingTrailingSlash];
    BOOL isDir = NO;
    NSNumber *exists = [self fileExistsAtPath:thePath isDirectory:&isDir error:error];
    if (exists == nil) {
        return NO;
    }
    if (![exists boolValue]) {
        return YES;
    }
    if (isDir) {
        if (![self removeDirectoryAtPath:thePath error:error]) {
            errorOccurred = YES;
            return NO;
        }
    } else {
        if (![self removeFileAtPath:thePath error:error]) {
            return NO;
        }
    }
    return YES;
}


- (BOOL)createDirectoryAtPath:(NSString *)thePath withIntermediateDirectories:(BOOL)createIntermediates error:(NSError **)error {
    thePath = [thePath stringByDeletingTrailingSlash];
    if (![thePath hasPrefix:@"/"]) {
        SETNSERROR([self errorDomain], -1, @"can't create directory (doesn't begin with a slash): %@", thePath);
        return NO;
    }
    
    if (createIntermediates && ![thePath isEqualToString:@"/"]) {
        NSString *parentPath = [thePath stringByDeletingLastPathComponent];
        BOOL isDirectory = NO;
        NSNumber *exists = [self fileExistsAtPath:parentPath isDirectory:&isDirectory error:error];
        if (exists == nil) {
            errorOccurred = YES;
            return NO;
        }
        if ([exists boolValue]) {
            if (!isDirectory) {
                SETNSERROR([self errorDomain], -1, @"%@ exists and is not a directory", parentPath);
                return NO;
            }
        } else {
            if (![self createDirectoryAtPath:parentPath withIntermediateDirectories:YES error:error]) {
                errorOccurred = YES;
                return NO;
            }
        }
    }
    HSLogDebug(@"libssh2_sftp_mkdir_ex(%@)", thePath);
    int ret = libssh2_sftp_mkdir_ex(sftp, (char *)[thePath UTF8String], strlen([thePath UTF8String]), LIBSSH2_SFTP_S_IRWXU|LIBSSH2_SFTP_S_IRWXG|LIBSSH2_SFTP_S_IRWXO);
    if (ret) {
        char *msg = NULL;
        int sessionError = libssh2_session_last_error(session, &msg, NULL, 0);
        if (sessionError == LIBSSH2_ERROR_SFTP_PROTOCOL) {
            unsigned long sftpError = libssh2_sftp_last_error(sftp);
            NSError *myError = [NSError errorWithDomain:[self errorDomain] code:sftpError userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                                                    [NSNumber numberWithInt:sessionError], @"libssh2SessionError",
                                                                                                    [NSNumber numberWithInt:sftpError], @"libssh2SFTPError",
                                                                                                    [NSString stringWithFormat:@"sftp mkdir(%@) error: %@", thePath, [self descriptionForSFTPStatusCode:sftpError]], NSLocalizedDescriptionKey,
                                                                                                    nil]];
            SETERRORFROMMYERROR;
        } else {
            NSError *myError = [NSError errorWithDomain:[self errorDomain] code:sessionError userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                                                       [NSNumber numberWithInt:sessionError], @"libssh2SessionError",
                                                                                                       [NSString stringWithFormat:@"sftp mkdir(%@) error: %s", thePath, msg], NSLocalizedDescriptionKey,
                                                                                                       nil]];
            SETERRORFROMMYERROR;
        }
        errorOccurred = YES;
        return NO;
    }
    return YES;
}

- (BOOL)ensureParentPathExistsForPath:(NSString *)thePath error:(NSError **)error {
    thePath = [thePath stringByDeletingTrailingSlash];
    NSString *parentPath = [thePath stringByDeletingLastPathComponent];
    BOOL isDirectory = NO;
    NSNumber *exists = [self fileExistsAtPath:parentPath isDirectory:&isDirectory error:error];
    if (exists == nil) {
        return NO;
    }
    if ([exists boolValue]) {
        if (!isDirectory) {
            SETNSERROR([self errorDomain], -1, @"Parent path %@ exists and is not a directory", parentPath);
            return NO;
        }
    } else {
        if (![self createDirectoryAtPath:parentPath withIntermediateDirectories:YES error:error]) {
            return NO;
        }
    }
    return YES;
}

- (NSNumber *)sizeOfItemAtPath:(NSString *)thePath error:(NSError **)error {
    thePath = [thePath stringByDeletingTrailingSlash];
    BOOL isDir = NO;
    unsigned long long dataSize = 0;
    NSNumber *exists = [self fileExistsAtPath:thePath isDirectory:&isDir dataSize:&dataSize lastModifiedDate:NULL error:error];
    if (exists == nil) {
        return nil;
    }
    if (![exists boolValue]) {
        HSLogDebug(@"path %@ does not exist; returning size = 0", thePath);
        return [NSNumber numberWithUnsignedInteger:0];
    }
    
    NSNumber *ret = nil;
    if (isDir) {
        ret = [self sizeOfDirectoryAtPath:thePath error:error];
    } else {
        ret = [NSNumber numberWithUnsignedLongLong:dataSize];
    }
    return ret;
}


- (NSArray *)objectsAtPath:(NSString *)thePath error:(NSError **)error {
    thePath = [thePath stringByDeletingTrailingSlash];
    BOOL isDir = NO;
    unsigned long long dataSize = NULL;
    NSDate *lastModifiedDate = nil;
    NSError *myError = nil;
    NSNumber *exists = [self fileExistsAtPath:thePath isDirectory:&isDir dataSize:&dataSize lastModifiedDate:&lastModifiedDate error:&myError];
    if (exists == nil) {
        SETERRORFROMMYERROR;
        return nil;
    }
    
    NSArray *ret = nil;
    if (![exists boolValue]) {
        ret = [NSArray array];
    } else if (isDir) {
        ret = [self objectsInDirectory:thePath error:error];
    } else {
        S3ObjectMetadata *md = [[[S3ObjectMetadata alloc] initWithPath:thePath lastModified:lastModifiedDate size:dataSize storageClass:@"STANDARD"] autorelease];
        ret = [NSArray arrayWithObject:md];
    }
    return ret;
}


- (NSArray *)pathsOfObjectsAtPath:(NSString *)thePath error:(NSError **)error {
    thePath = [thePath stringByDeletingTrailingSlash];
    BOOL isDir = NO;
    unsigned long long dataSize = NULL;
    NSDate *lastModifiedDate = nil;
    NSError *myError = nil;
    NSNumber *exists = [self fileExistsAtPath:thePath isDirectory:&isDir dataSize:&dataSize lastModifiedDate:&lastModifiedDate error:&myError];
    if (exists == nil) {
        SETERRORFROMMYERROR;
        return nil;
    }
    
    NSArray *ret = nil;
    if (![exists boolValue]) {
        ret = [NSArray array];
    } else if (isDir) {
        ret = [self pathsOfObjectsInDirectory:thePath error:error];
    } else {
        ret = [NSArray arrayWithObject:thePath];
    }
    return ret;
}



#pragma mark internal
- (NSNumber *)fileExistsAtPath:(NSString *)thePath isDirectory:(BOOL *)isDirectory dataSize:(unsigned long long *)theDataSize lastModifiedDate:(NSDate **)theLastModifiedDate error:(NSError **)error {
    LIBSSH2_SFTP_ATTRIBUTES attrs;
    
    HSLogDebug(@"libssh2_sftp_lstat(%@)", thePath);
    if (libssh2_sftp_lstat(sftp, (char *)[thePath UTF8String], &attrs)) {
        char *msg = NULL;
        int sessionError = libssh2_session_last_error(session, &msg, NULL, 0);
        if (sessionError == LIBSSH2_ERROR_SFTP_PROTOCOL) {
            unsigned long sftpError = libssh2_sftp_last_error(sftp);
            // SFTP servers can return access-denied if the parent directory doesn't exist:
            if (sftpError == LIBSSH2_FX_NO_SUCH_FILE || sftpError == LIBSSH2_FX_PERMISSION_DENIED) {
                return [NSNumber numberWithBool:NO];
            }
            
            NSError *myError = [NSError errorWithDomain:[self errorDomain] code:sftpError userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                                                    [NSNumber numberWithInt:sessionError], @"libssh2SessionError",
                                                                                                    [NSNumber numberWithInt:sftpError], @"libssh2SFTPError",
                                                                                                    [NSString stringWithFormat:@"sftp lstat(%@) error: %@", thePath, [self descriptionForSFTPStatusCode:sftpError]], NSLocalizedDescriptionKey,
                                                                                                    nil]];
            SETERRORFROMMYERROR;
        } else {
            NSError *myError = [NSError errorWithDomain:[self errorDomain] code:sessionError userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                                                       [NSNumber numberWithInt:sessionError], @"libssh2SessionError",
                                                                                                       [NSString stringWithFormat:@"sftp lstat(%@) error: %s", thePath, msg], NSLocalizedDescriptionKey,
                                                                                                       nil]];
            SETERRORFROMMYERROR;
        }
        errorOccurred = YES;
        return nil;
    }
    if (isDirectory != NULL) {
        if ((attrs.flags & LIBSSH2_SFTP_ATTR_PERMISSIONS) == 0) {
            SETNSERROR([self errorDomain], -1, @"Permissions attribute not available");
            return nil;
        }
        *isDirectory = S_ISDIR(attrs.permissions);
    }
    if (theDataSize != NULL) {
        if ((attrs.flags & LIBSSH2_SFTP_ATTR_SIZE) == 0) {
            SETNSERROR([self errorDomain], -1, @"Size attribute not available");
            return nil;
        }
        *theDataSize = attrs.filesize;
    }
    if (theLastModifiedDate != NULL) {
        if ((attrs.flags & LIBSSH2_SFTP_ATTR_ACMODTIME) == 0) {
            SETNSERROR([self errorDomain], -1, @"Last modified time not available");
            return nil;
        }
        *theLastModifiedDate = [NSDate dateWithTimeIntervalSince1970:(double)attrs.mtime];
    }
    return [NSNumber numberWithBool:YES];
}
- (BOOL)doWriteData:(NSData *)theData toFileAtPath:(NSString *)thePath dataTransferDelegate:(id <DataTransferDelegate>)theDelegate error:(NSError **)error {
    // Delete trailing slash if any, to avoid permission-denied or other errors from SFTP servers:
    thePath = [thePath stringByDeletingTrailingSlash];
    
    HSLogDebug(@"writing %lu bytes to %@:%@", (unsigned long)[theData length], hostname, thePath);
    
    HSLogDebug(@"libssh2_sftp_open_ex(%@)", thePath);
    LIBSSH2_SFTP_HANDLE *handle = libssh2_sftp_open_ex(sftp,
                                                       (char *)[thePath UTF8String],
                                                       strlen([thePath UTF8String]),
                                                       LIBSSH2_FXF_WRITE|LIBSSH2_FXF_CREAT|LIBSSH2_FXF_TRUNC,
                                                       LIBSSH2_SFTP_S_IRWXU|LIBSSH2_SFTP_S_IRWXG|LIBSSH2_SFTP_S_IRWXO,
                                                       LIBSSH2_SFTP_OPENFILE);
    if (handle == NULL) {
        char *msg = NULL;
        int sessionError = libssh2_session_last_error(session, &msg, NULL, 0);
        if (sessionError == LIBSSH2_ERROR_SFTP_PROTOCOL) {
            unsigned long sftpError = libssh2_sftp_last_error(sftp);
            NSError *myError = [NSError errorWithDomain:[self errorDomain] code:sftpError userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                                                    [NSNumber numberWithInt:sessionError], @"libssh2SessionError",
                                                                                                    [NSNumber numberWithInt:sftpError], @"libssh2SFTPError",
                                                                                                    [NSString stringWithFormat:@"sftp open(%@) for writing error: %@", thePath, [self descriptionForSFTPStatusCode:sftpError]], NSLocalizedDescriptionKey,
                                                                                                    nil]];
            SETERRORFROMMYERROR;
        } else {
            NSError *myError = [NSError errorWithDomain:[self errorDomain] code:sessionError userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                                                       [NSNumber numberWithInt:sessionError], @"libssh2SessionError",
                                                                                                       [NSString stringWithFormat:@"sftp open(%@) for writing error: %s", thePath, msg], NSLocalizedDescriptionKey,
                                                                                                       nil]];
            SETERRORFROMMYERROR;
        }
        errorOccurred = YES;
        return NO;
    }
    BOOL ret = YES;
    unsigned char *bytes = (unsigned char *)[theData bytes];
    ssize_t total = [theData length];
    ssize_t sent = 0;
    NetMonitor *netMonitor = [[[NetMonitor alloc] init] autorelease];
    ssize_t lastSentLength = 0;
    NSTimeInterval lastSentTime = 0;
    HTTPThrottleType throttleType = HTTP_THROTTLE_TYPE_NONE;
    NSUInteger throttleKBPS = 0;
    
    while (sent < total) {
        size_t len = total - sent;
        NSTimeInterval currentTime = [NSDate timeIntervalSinceReferenceDate];
        if (throttleType == HTTP_THROTTLE_TYPE_FIXED && throttleKBPS != 0) {
            // Don't send more than 1/10th of the max bytes/sec:
            NSUInteger maxLen = throttleKBPS * 100;
            if (len > maxLen) {
                len = maxLen;
            }
            
            if (lastSentTime != 0) {
                NSTimeInterval interval = currentTime - lastSentTime;
                
                // For some reason Activity Monitor reports "Data sent/sec" at twice what we seem to be sending!
                // So we send half as much -- we divide by 500 instead of 1000 here:
                NSTimeInterval throttledInterval = (double)lastSentLength / ((double)throttleKBPS * (double)500.0);
                
                if (throttledInterval > interval) {
                    [NSThread sleepForTimeInterval:(throttledInterval - interval)];
                }
            }
        }
        
        if (throttleType == HTTP_THROTTLE_TYPE_AUTOMATIC) {
            NSTimeInterval interval = currentTime - lastSentTime;
            if (lastSentLength > 0) {
                double myBPS = (double)lastSentLength / interval;
                double throttle = [netMonitor sample:myBPS];
                if (throttle < 1.0) {
                    HSLogDebug(@"throttle = %f", throttle);
                }
                NSTimeInterval throttledInterval = (throttle == 0) ? 0.5 : ((interval / throttle) - interval);
                if (throttledInterval > 0) {
                    if (throttledInterval > 0.5) {
                        throttledInterval = 0.5;
                    }
                    HSLogDebug(@"auto-throttle: sleeping %f seconds", throttledInterval);
                    [NSThread sleepForTimeInterval:throttledInterval];
                }
            }
        }
        
        HSLogDebug(@"attempting to SFTP write bytes %ld to %ld to %@", sent, (sent+len), thePath);
        ssize_t sentThisTime = libssh2_sftp_write(handle, bytes + sent, len);
        if (sentThisTime < 0) {
            char *msg = NULL;
            int sessionError = libssh2_session_last_error(session, &msg, NULL, 0);
            if (sessionError == LIBSSH2_ERROR_SFTP_PROTOCOL) {
                unsigned long sftpError = libssh2_sftp_last_error(sftp);
                NSError *myError = [NSError errorWithDomain:[self errorDomain] code:sftpError userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                                                        [NSNumber numberWithInt:sessionError], @"libssh2SessionError",
                                                                                                        [NSNumber numberWithInt:sftpError], @"libssh2SFTPError",
                                                                                                        [NSString stringWithFormat:@"sftp write(%@) error: %@", thePath, [self descriptionForSFTPStatusCode:sftpError]], NSLocalizedDescriptionKey,
                                                                                                        nil]];
                SETERRORFROMMYERROR;
            } else {
                NSError *myError = [NSError errorWithDomain:[self errorDomain] code:sessionError userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                                                           [NSNumber numberWithInt:sessionError], @"libssh2SessionError",
                                                                                                           [NSString stringWithFormat:@"sftp write(%@) error: %s", thePath, msg], NSLocalizedDescriptionKey,
                                                                                                           nil]];
                SETERRORFROMMYERROR;
            }
            
            errorOccurred = YES;
            ret = NO;
            break;
        }
        
        sent += sentThisTime;
        lastSentTime = currentTime;
        lastSentLength = sentThisTime;
        
        HTTPThrottle *httpThrottle = nil;
        if (theDelegate != nil && ![theDelegate dataTransferDidUploadBytes:sentThisTime httpThrottle:&httpThrottle error:error]) {
            errorOccurred = YES;
            ret = NO;
            break;
        }
        throttleType = [httpThrottle throttleType];
        throttleKBPS = [httpThrottle throttleKBPS];
    }
    if (libssh2_sftp_close(handle) < 0) {
        errorOccurred = YES;
    }
    if (ret) {
        HSLogDebug(@"wrote %lu bytes to %@:%@", (unsigned long)[theData length], hostname, thePath);
    }
    return ret;
}
- (BOOL)removeFileAtPath:(NSString *)thePath error:(NSError **)error {
    // Delete trailing slash if any, to avoid permission-denied or other errors from SFTP servers:
    thePath = [thePath stringByDeletingTrailingSlash];
    
    HSLogDebug(@"libssh2_sftp_unlink_ex(%@)", thePath);
    if (libssh2_sftp_unlink_ex(sftp, (char *)[thePath UTF8String], strlen([thePath UTF8String])) == -1) {
        char *msg = NULL;
        int sessionError = libssh2_session_last_error(session, &msg, NULL, 0);
        if (sessionError == LIBSSH2_ERROR_SFTP_PROTOCOL) {
            unsigned long sftpError = libssh2_sftp_last_error(sftp);
            NSError *myError = [NSError errorWithDomain:[self errorDomain] code:sftpError userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                                                    [NSNumber numberWithInt:sessionError], @"libssh2SessionError",
                                                                                                    [NSNumber numberWithInt:sftpError], @"libssh2SFTPError",
                                                                                                    [NSString stringWithFormat:@"sftp unlink(%@) error: %@", thePath, [self descriptionForSFTPStatusCode:sftpError]], NSLocalizedDescriptionKey,
                                                                                                    nil]];
            SETERRORFROMMYERROR;
        } else {
            NSError *myError = [NSError errorWithDomain:[self errorDomain] code:sessionError userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                                                       [NSNumber numberWithInt:sessionError], @"libssh2SessionError",
                                                                                                       [NSString stringWithFormat:@"sftp unlink(%@) error: %s", thePath, msg], NSLocalizedDescriptionKey,
                                                                                                       nil]];
            SETERRORFROMMYERROR;
        }
        errorOccurred = YES;
        return NO;
    }
    return YES;
}
- (BOOL)removeDirectoryAtPath:(NSString *)thePath error:(NSError **)error {
    // Delete trailing slash if any, to avoid permission-denied or other errors from SFTP servers:
    thePath = [thePath stringByDeletingTrailingSlash];
    
    HSLogDebug(@"libssh2_sftp_opendir(%@)", thePath);
    LIBSSH2_SFTP_HANDLE *handle = libssh2_sftp_opendir(sftp, (char *)[thePath UTF8String]);
    if (handle == NULL) {
        char *msg = NULL;
        int sessionError = libssh2_session_last_error(session, &msg, NULL, 0);
        if (sessionError == LIBSSH2_ERROR_SFTP_PROTOCOL) {
            unsigned long sftpError = libssh2_sftp_last_error(sftp);
            // SFTP servers can return access-denied if the parent directory doesn't exist:
            if (sftpError == LIBSSH2_FX_NO_SUCH_FILE || sftpError == LIBSSH2_FX_PERMISSION_DENIED) {
                return [NSArray array];
            }
            
            NSError *myError = [NSError errorWithDomain:[self errorDomain] code:sftpError userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                                                    [NSNumber numberWithInt:sessionError], @"libssh2SessionError",
                                                                                                    [NSNumber numberWithInt:sftpError], @"libssh2SFTPError",
                                                                                                    [NSString stringWithFormat:@"sftp opendir(%@) error: %@", thePath, [self descriptionForSFTPStatusCode:sftpError]], NSLocalizedDescriptionKey,
                                                                                                    nil]];
            SETERRORFROMMYERROR;
        } else {
            NSError *myError = [NSError errorWithDomain:[self errorDomain] code:sessionError userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                                                       [NSNumber numberWithInt:sessionError], @"libssh2SessionError",
                                                                                                       [NSString stringWithFormat:@"sftp opendir(%@) error: %s", thePath, msg], NSLocalizedDescriptionKey,
                                                                                                       nil]];
            SETERRORFROMMYERROR;
        }
        errorOccurred = YES;
        return nil;
    }
    
    BOOL ret = YES;
    char buf[BUFLEN];
    for (;;) {
        LIBSSH2_SFTP_ATTRIBUTES attrs;
        int rc = libssh2_sftp_readdir(handle, buf, BUFLEN, &attrs);
        if (rc < 0) {
            char *msg = NULL;
            int sessionError = libssh2_session_last_error(session, &msg, NULL, 0);
            if (sessionError == LIBSSH2_ERROR_SFTP_PROTOCOL) {
                unsigned long sftpError = libssh2_sftp_last_error(sftp);
                NSError *myError = [NSError errorWithDomain:[self errorDomain] code:sftpError userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                                                        [NSNumber numberWithInt:sessionError], @"libssh2SessionError",
                                                                                                        [NSNumber numberWithInt:sftpError], @"libssh2SFTPError",
                                                                                                        [NSString stringWithFormat:@"sftp readdir(%@) error: %@", thePath, [self descriptionForSFTPStatusCode:sftpError]], NSLocalizedDescriptionKey,
                                                                                                        nil]];
                SETERRORFROMMYERROR;
            } else {
                NSError *myError = [NSError errorWithDomain:[self errorDomain] code:sessionError userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                                                           [NSNumber numberWithInt:sessionError], @"libssh2SessionError",
                                                                                                           [NSString stringWithFormat:@"sftp readdir(%@) error: %s", thePath, msg], NSLocalizedDescriptionKey,
                                                                                                           nil]];
                SETERRORFROMMYERROR;
            }
            errorOccurred = YES;
            ret = NO;
            break;
        } else if (rc > 0) {
            NSString *name = [[[NSString alloc] initWithBytes:buf length:rc encoding:NSUTF8StringEncoding] autorelease];
            if (![name isEqualToString:@"."] && ![name isEqualToString:@".."]) {
                NSString *childPath = [thePath stringByAppendingPathComponent:name];
                if ((attrs.flags & LIBSSH2_SFTP_ATTR_PERMISSIONS) == 0) {
                    SETNSERROR([self errorDomain], -1, @"Permissions attribute not available");
                    ret = NO;
                    break;
                }
                if (S_ISDIR(attrs.permissions)) {
                    if (![self removeDirectoryAtPath:childPath error:error]) {
                        ret = NO;
                        break;
                    }
                } else {
                    if (![self removeFileAtPath:childPath error:error]) {
                        ret = NO;
                        break;
                    }
                }
            }
        } else {
            break;
        }
    }
    if (libssh2_sftp_closedir(handle) < 0) {
        errorOccurred = YES;
    }
    if (!ret) {
        return NO;
    }
    
    HSLogDebug(@"libssh2_sftp_rmdir_ex(%@)", thePath);
    if (libssh2_sftp_rmdir_ex(sftp, [thePath UTF8String], strlen([thePath UTF8String]))) {
        char *msg = NULL;
        int sessionError = libssh2_session_last_error(session, &msg, NULL, 0);
        if (sessionError == LIBSSH2_ERROR_SFTP_PROTOCOL) {
            unsigned long sftpError = libssh2_sftp_last_error(sftp);
            NSError *myError = [NSError errorWithDomain:[self errorDomain] code:sftpError userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                                                    [NSNumber numberWithInt:sessionError], @"libssh2SessionError",
                                                                                                    [NSNumber numberWithInt:sftpError], @"libssh2SFTPError",
                                                                                                    [NSString stringWithFormat:@"sftp rmdir(%@) error: %@", thePath, [self descriptionForSFTPStatusCode:sftpError]], NSLocalizedDescriptionKey,
                                                                                                    nil]];
            SETERRORFROMMYERROR;
        } else {
            NSError *myError = [NSError errorWithDomain:[self errorDomain] code:sessionError userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                                                       [NSNumber numberWithInt:sessionError], @"libssh2SessionError",
                                                                                                       [NSString stringWithFormat:@"sftp rmdir(%@) error: %s", thePath, msg], NSLocalizedDescriptionKey,
                                                                                                       nil]];
            SETERRORFROMMYERROR;
        }
        errorOccurred = YES;
        return NO;
    }
    return YES;
}
- (NSNumber *)sizeOfDirectoryAtPath:(NSString *)thePath error:(NSError **)error {
    // Delete trailing slash if any, to avoid permission-denied or other errors from SFTP servers:
    thePath = [thePath stringByDeletingTrailingSlash];
    
    HSLogDebug(@"libssh2_sftp_opendir(%@)", thePath);
    LIBSSH2_SFTP_HANDLE *handle = libssh2_sftp_opendir(sftp, (char *)[thePath UTF8String]);
    if (handle == NULL) {
        char *msg = NULL;
        int sessionError = libssh2_session_last_error(session, &msg, NULL, 0);
        if (sessionError == LIBSSH2_ERROR_SFTP_PROTOCOL) {
            unsigned long sftpError = libssh2_sftp_last_error(sftp);
            NSError *myError = [NSError errorWithDomain:[self errorDomain] code:sftpError userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                                                    [NSNumber numberWithInt:sessionError], @"libssh2SessionError",
                                                                                                    [NSNumber numberWithInt:sftpError], @"libssh2SFTPError",
                                                                                                    [NSString stringWithFormat:@"sftp opendir(%@) error: %@", thePath, [self descriptionForSFTPStatusCode:sftpError]], NSLocalizedDescriptionKey,
                                                                                                    nil]];
            SETERRORFROMMYERROR;
        } else {
            NSError *myError = [NSError errorWithDomain:[self errorDomain] code:sessionError userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                                                       [NSNumber numberWithInt:sessionError], @"libssh2SessionError",
                                                                                                       [NSString stringWithFormat:@"sftp opendir(%@) error: %s", thePath, msg], NSLocalizedDescriptionKey,
                                                                                                       nil]];
            SETERRORFROMMYERROR;
        }
        errorOccurred = YES;
        return nil;
    }
    
    BOOL ret = YES;
    unsigned long long total = 0;
    char buf[BUFLEN];
    for (;;) {
        LIBSSH2_SFTP_ATTRIBUTES attrs;
        int rc = libssh2_sftp_readdir(handle, buf, BUFLEN, &attrs);
        if (rc < 0) {
            char *msg = NULL;
            int sessionError = libssh2_session_last_error(session, &msg, NULL, 0);
            if (sessionError == LIBSSH2_ERROR_SFTP_PROTOCOL) {
                unsigned long sftpError = libssh2_sftp_last_error(sftp);
                NSError *myError = [NSError errorWithDomain:[self errorDomain] code:sftpError userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                                                        [NSNumber numberWithInt:sessionError], @"libssh2SessionError",
                                                                                                        [NSNumber numberWithInt:sftpError], @"libssh2SFTPError",
                                                                                                        [NSString stringWithFormat:@"sftp readdir(%@) error: %@", thePath, [self descriptionForSFTPStatusCode:sftpError]], NSLocalizedDescriptionKey,
                                                                                                        nil]];
                SETERRORFROMMYERROR;
            } else {
                NSError *myError = [NSError errorWithDomain:[self errorDomain] code:sessionError userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                                                           [NSNumber numberWithInt:sessionError], @"libssh2SessionError",
                                                                                                           [NSString stringWithFormat:@"sftp readdir(%@) error: %s", thePath, msg], NSLocalizedDescriptionKey,
                                                                                                           nil]];
                SETERRORFROMMYERROR;
            }
            errorOccurred = YES;
            ret = NO;
            break;
        } else if (rc > 0) {
            NSString *name = [[[NSString alloc] initWithBytes:buf length:rc encoding:NSUTF8StringEncoding] autorelease];
            if (![name isEqualToString:@"."] && ![name isEqualToString:@".."]) {
                if ((attrs.flags & LIBSSH2_SFTP_ATTR_PERMISSIONS) == 0) {
                    SETNSERROR([self errorDomain], -1, @"Permissions attribute not available");
                    ret = NO;
                    break;
                }
                if (S_ISDIR(attrs.permissions)) {
                    NSString *childPath = [thePath stringByAppendingPathComponent:name];
                    NSNumber *childSize = [self sizeOfDirectoryAtPath:childPath error:error];
                    if (childSize == nil) {
                        ret = NO;
                        break;
                    }
                    total += [childSize unsignedLongLongValue];
                } else {
                    if ((attrs.flags & LIBSSH2_SFTP_ATTR_SIZE) == 0) {
                        SETNSERROR([self errorDomain], -1, @"Size attribute not available");
                        ret = NO;
                        break;
                    }
                    total += attrs.filesize;
                }
            }
        } else {
            break;
        }
    }
    if (libssh2_sftp_closedir(handle) < 0) {
        errorOccurred = YES;
    }
    
    if (!ret) {
        return nil;
    }
    
    return [NSNumber numberWithUnsignedLongLong:total];
}
- (NSArray *)objectsInDirectory:(NSString *)thePath error:(NSError **)error {
    // Delete trailing slash if any, to avoid permission-denied or other errors from SFTP servers:
    thePath = [thePath stringByDeletingTrailingSlash];
    
    HSLogDebug(@"libssh2_sftp_opendir(%@)", thePath);
    LIBSSH2_SFTP_HANDLE *handle = libssh2_sftp_opendir(sftp, (char *)[thePath UTF8String]);
    if (handle == NULL) {
        char *msg = NULL;
        int sessionError = libssh2_session_last_error(session, &msg, NULL, 0);
        if (sessionError == LIBSSH2_ERROR_SFTP_PROTOCOL) {
            unsigned long sftpError = libssh2_sftp_last_error(sftp);
            NSError *myError = [NSError errorWithDomain:[self errorDomain] code:sftpError userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                                                    [NSNumber numberWithInt:sessionError], @"libssh2SessionError",
                                                                                                    [NSNumber numberWithInt:sftpError], @"libssh2SFTPError",
                                                                                                    [NSString stringWithFormat:@"sftp opendir(%@) error: %@", thePath, [self descriptionForSFTPStatusCode:sftpError]], NSLocalizedDescriptionKey,
                                                                                                    nil]];
            SETERRORFROMMYERROR;
        } else {
            NSError *myError = [NSError errorWithDomain:[self errorDomain] code:sessionError userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                                                       [NSNumber numberWithInt:sessionError], @"libssh2SessionError",
                                                                                                       [NSString stringWithFormat:@"sftp opendir(%@) error: %s", thePath, msg], NSLocalizedDescriptionKey,
                                                                                                       nil]];
            SETERRORFROMMYERROR;
        }
        errorOccurred = YES;
        return nil;
    }
    
    NSMutableArray *ret = [NSMutableArray array];
    char buf[BUFLEN];
    for (;;) {
        LIBSSH2_SFTP_ATTRIBUTES attrs;
        int rc = libssh2_sftp_readdir(handle, buf, BUFLEN, &attrs);
        if (rc < 0) {
            char *msg = NULL;
            int sessionError = libssh2_session_last_error(session, &msg, NULL, 0);
            if (sessionError == LIBSSH2_ERROR_SFTP_PROTOCOL) {
                unsigned long sftpError = libssh2_sftp_last_error(sftp);
                NSError *myError = [NSError errorWithDomain:[self errorDomain] code:sftpError userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                                                        [NSNumber numberWithInt:sessionError], @"libssh2SessionError",
                                                                                                        [NSNumber numberWithInt:sftpError], @"libssh2SFTPError",
                                                                                                        [NSString stringWithFormat:@"sftp readdir(%@) error: %@", thePath, [self descriptionForSFTPStatusCode:sftpError]], NSLocalizedDescriptionKey,
                                                                                                        nil]];
                SETERRORFROMMYERROR;
            } else {
                NSError *myError = [NSError errorWithDomain:[self errorDomain] code:sessionError userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                                                           [NSNumber numberWithInt:sessionError], @"libssh2SessionError",
                                                                                                           [NSString stringWithFormat:@"sftp readdir(%@) error: %s", thePath, msg], NSLocalizedDescriptionKey,
                                                                                                           nil]];
                SETERRORFROMMYERROR;
            }
            errorOccurred = YES;
            ret = nil;
            break;
        } else if (rc > 0) {
            NSString *name = [[[NSString alloc] initWithBytes:buf length:rc encoding:NSUTF8StringEncoding] autorelease];
            if (![name isEqualToString:@"."] && ![name isEqualToString:@".."]) {
                if ((attrs.flags & LIBSSH2_SFTP_ATTR_PERMISSIONS) == 0) {
                    SETNSERROR([self errorDomain], -1, @"Permissions attribute not available");
                    ret = nil;
                    break;
                }
                NSString *childPath = [thePath stringByAppendingPathComponent:name];
                if (S_ISDIR(attrs.permissions)) {
                    NSArray *childObjects = [self objectsInDirectory:childPath error:error];
                    if (childObjects == nil) {
                        ret = nil;
                        break;
                    }
                    [ret addObjectsFromArray:childObjects];
                } else {
                    if ((attrs.flags & LIBSSH2_SFTP_ATTR_SIZE) == 0) {
                        SETNSERROR([self errorDomain], -1, @"Size attribute not available");
                        ret = nil;
                        break;
                    }
                    if ((attrs.flags & LIBSSH2_SFTP_ATTR_ACMODTIME) == 0) {
                        SETNSERROR([self errorDomain], -1, @"Mod time attribute not available");
                        ret = nil;
                        break;
                    }
                    NSDate *date = [NSDate dateWithTimeIntervalSince1970:(double)attrs.mtime];
                    S3ObjectMetadata *md = [[[S3ObjectMetadata alloc] initWithPath:childPath lastModified:date size:(long)attrs.filesize storageClass:@"STANDARD"] autorelease];
                    [ret addObject:md];
                }
            }
        } else {
            break;
        }
    }
    if (libssh2_sftp_closedir(handle) < 0) {
        errorOccurred = YES;
    }
    
    return ret;
}
- (NSArray *)pathsOfObjectsInDirectory:(NSString *)thePath error:(NSError **)error {
    // Delete trailing slash if any, to avoid permission-denied or other errors from SFTP servers:
    thePath = [thePath stringByDeletingTrailingSlash];
    
    HSLogDebug(@"libssh2_sftp_opendir(%@)", thePath);
    LIBSSH2_SFTP_HANDLE *handle = libssh2_sftp_opendir(sftp, (char *)[thePath UTF8String]);
    if (handle == NULL) {
        char *msg = NULL;
        int sessionError = libssh2_session_last_error(session, &msg, NULL, 0);
        if (sessionError == LIBSSH2_ERROR_SFTP_PROTOCOL) {
            unsigned long sftpError = libssh2_sftp_last_error(sftp);
            NSError *myError = [NSError errorWithDomain:[self errorDomain] code:sftpError userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                                                    [NSNumber numberWithInt:sessionError], @"libssh2SessionError",
                                                                                                    [NSNumber numberWithInt:sftpError], @"libssh2SFTPError",
                                                                                                    [NSString stringWithFormat:@"sftp opendir(%@) error: %@", thePath, [self descriptionForSFTPStatusCode:sftpError]], NSLocalizedDescriptionKey,
                                                                                                    nil]];
            SETERRORFROMMYERROR;
        } else {
            NSError *myError = [NSError errorWithDomain:[self errorDomain] code:sessionError userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                                                       [NSNumber numberWithInt:sessionError], @"libssh2SessionError",
                                                                                                       [NSString stringWithFormat:@"sftp opendir(%@) error: %s", thePath, msg], NSLocalizedDescriptionKey,
                                                                                                       nil]];
            SETERRORFROMMYERROR;
        }
        errorOccurred = YES;
        return nil;
    }
    
    NSMutableArray *ret = [NSMutableArray array];
    char buf[BUFLEN];
    for (;;) {
        LIBSSH2_SFTP_ATTRIBUTES attrs;
        int rc = libssh2_sftp_readdir(handle, buf, BUFLEN, &attrs);
        if (rc < 0) {
            char *msg = NULL;
            int sessionError = libssh2_session_last_error(session, &msg, NULL, 0);
            if (sessionError == LIBSSH2_ERROR_SFTP_PROTOCOL) {
                unsigned long sftpError = libssh2_sftp_last_error(sftp);
                NSError *myError = [NSError errorWithDomain:[self errorDomain] code:sftpError userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                                                        [NSNumber numberWithInt:sessionError], @"libssh2SessionError",
                                                                                                        [NSNumber numberWithInt:sftpError], @"libssh2SFTPError",
                                                                                                        [NSString stringWithFormat:@"sftp readdir(%@) error: %@", thePath, [self descriptionForSFTPStatusCode:sftpError]], NSLocalizedDescriptionKey,
                                                                                                        nil]];
                SETERRORFROMMYERROR;
            } else {
                NSError *myError = [NSError errorWithDomain:[self errorDomain] code:sessionError userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                                                           [NSNumber numberWithInt:sessionError], @"libssh2SessionError",
                                                                                                           [NSString stringWithFormat:@"sftp readdir(%@) error: %s", thePath, msg], NSLocalizedDescriptionKey,
                                                                                                           nil]];
                SETERRORFROMMYERROR;
            }
            errorOccurred = YES;
            return nil;
        } else if (rc > 0) {
            NSString *name = [[[NSString alloc] initWithBytes:buf length:rc encoding:NSUTF8StringEncoding] autorelease];
            if (![name isEqualToString:@"."] && ![name isEqualToString:@".."]) {
                if ((attrs.flags & LIBSSH2_SFTP_ATTR_PERMISSIONS) == 0) {
                    SETNSERROR([self errorDomain], -1, @"Permissions attribute not available");
                    ret = nil;
                    break;
                }
                NSString *childPath = [thePath stringByAppendingPathComponent:name];
                if (S_ISDIR(attrs.permissions)) {
                    NSArray *childPaths = [self pathsOfObjectsInDirectory:childPath error:error];
                    if (childPaths == nil) {
                        ret = nil;
                        break;
                    }
                    [ret addObjectsFromArray:childPaths];
                } else {
                    if ((attrs.flags & LIBSSH2_SFTP_ATTR_SIZE) == 0) {
                        SETNSERROR([self errorDomain], -1, @"Size attribute not available");
                        ret = nil;
                        break;
                    }
                    if ((attrs.flags & LIBSSH2_SFTP_ATTR_ACMODTIME) == 0) {
                        SETNSERROR([self errorDomain], -1, @"Mod time attribute not available");
                        ret = nil;
                        break;
                    }
                    [ret addObject:childPath];
                }
            }
        } else {
            break;
        }
    }
    if (libssh2_sftp_closedir(handle) < 0) {
        errorOccurred = YES;
    }
    
    return ret;
}
- (NSString *)descriptionForSFTPStatusCode:(unsigned long)errnum {
    switch (errnum) {
        case LIBSSH2_FX_OK:
            return @"OK";
        case LIBSSH2_FX_EOF:
            return @"EOF";
        case LIBSSH2_FX_NO_SUCH_FILE:
            return @"No such file";
        case LIBSSH2_FX_PERMISSION_DENIED:
            return @"Permission denied";
        case LIBSSH2_FX_FAILURE:
            return @"Failure";
        case LIBSSH2_FX_BAD_MESSAGE:
            return @"Bad message";
        case LIBSSH2_FX_NO_CONNECTION:
            return @"No connection";
        case LIBSSH2_FX_CONNECTION_LOST:
            return @"Connection lost";
        case LIBSSH2_FX_OP_UNSUPPORTED:
            return @"Op unsupported";
        case LIBSSH2_FX_INVALID_HANDLE:
            return @"Invalid handle";
        case LIBSSH2_FX_NO_SUCH_PATH:
            return @"No such path";
        case LIBSSH2_FX_FILE_ALREADY_EXISTS:
            return @"File already exists";
        case LIBSSH2_FX_WRITE_PROTECT:
            return @"Write protect";
        case LIBSSH2_FX_NO_MEDIA:
            return @"No media";
        case LIBSSH2_FX_NO_SPACE_ON_FILESYSTEM:
            return @"No space on filesystem";
        case LIBSSH2_FX_QUOTA_EXCEEDED:
            return @"Quota exceeded";
        case LIBSSH2_FX_UNKNOWN_PRINCIPLE:
            return @"Unknown principle";
        case LIBSSH2_FX_LOCK_CONFlICT:
            return @"Lock conflict";
        case LIBSSH2_FX_DIR_NOT_EMPTY:
            return @"Dir not empty";
        case LIBSSH2_FX_NOT_A_DIRECTORY:
            return @"Not a directory";
        case LIBSSH2_FX_INVALID_FILENAME:
            return @"Invalid filename";
        case LIBSSH2_FX_LINK_LOOP:
            return @"Link loop";
    }
    return @"Unknown SFTP error code";
}
@end

#pragma clang diagnostic pop
