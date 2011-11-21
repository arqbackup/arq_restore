/*
 Copyright (c) 2009, Stefan Reitshamer http://www.haystacksoftware.com
 
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

#import "ArqRestoreCommand.h"
#import "SetNSError.h"
#import "S3AuthorizationProvider.h"
#import "S3Service.h"
#import "RegexKitLite.h"
#import "DictNode.h"
#import "HTTP.h"
#import "Restorer.h"
#import "NSErrorCodes.h"
#import "NSError_extra.h"
#import "UserAndComputer.h"
#import "ArqSalt.h"
#import "ArqRepo.h"
#import "BackupSet.h"
#import "ReflogPrinter.h"


@interface ArqRestoreCommand (internal)
- (BOOL)printArqFolders:(NSError **)error;
- (BOOL)processPath:(NSError **)error;
- (BOOL)validateS3Keys:(NSError **)error;
@end

@implementation ArqRestoreCommand
- (id)init {
    if (self = [super init]) {
        char *theAccessKey = getenv("ARQ_ACCESS_KEY");
        if (theAccessKey != NULL) {
            accessKey = [[NSString alloc] initWithUTF8String:theAccessKey];
        }
        char *theSecretKey = getenv("ARQ_SECRET_KEY");
        if (theSecretKey != NULL) {
            secretKey = [[NSString alloc] initWithUTF8String:theSecretKey];
        }
        char *theEncryptionPassword = getenv("ARQ_ENCRYPTION_PASSWORD");
        if (theEncryptionPassword != NULL) {
            encryptionPassword = [[NSString alloc] initWithUTF8String:theEncryptionPassword];
        }
        if (accessKey != nil && secretKey != nil) {
            S3AuthorizationProvider *sap = [[S3AuthorizationProvider alloc] initWithAccessKey:accessKey secretKey:secretKey];
            s3 = [[S3Service alloc] initWithS3AuthorizationProvider:sap useSSL:NO retryOnTransientError:YES];
            [sap release];
        }
    }
    return self;
}
- (void)dealloc {
    [accessKey release];
    [secretKey release];
    [encryptionPassword release];
    [s3 release];
    [path release];
    [commitSHA1 release];
    [super dealloc];
}
- (BOOL)readArgc:(int)argc argv:(const char **)argv {
    for (int i = 1; i < argc; i++) {
        if (*argv[i] == '-') {
            if (strcmp(argv[i], "-l")) {
                fprintf(stderr, "invalid argument\n");
                return NO;
            }
            if (argc <= i+1) {
                fprintf(stderr, "missing log_level argument (error,warn,info,debug or trace)\n");
                return NO;
            }
            i++;
            NSString *level = [NSString stringWithUTF8String:argv[i]];
            setHSLogLevel(hsLogLevelForName(level));
        } else if (path == nil) {
            path = [[NSString alloc] initWithUTF8String:argv[i]];
        } else if (commitSHA1 == nil) {
            commitSHA1 = [[NSString alloc] initWithUTF8String:argv[i]];
        } else {
            fprintf(stderr, "warning: ignoring argument '%s'\n", argv[i]);
        }
    }
    return YES;
}
- (BOOL)execute:(NSError **)error {
    BOOL ret = YES;
    if (path == nil) {
        ret = [self printArqFolders:error];
    } else {
        ret = [self processPath:error];
    }        
    return ret;
}
@end

@implementation ArqRestoreCommand (internal)
- (BOOL)printArqFolders:(NSError **)error {
    if (![self validateS3Keys:error]) {
        return NO;
    }

    NSArray *backupSets = [BackupSet allBackupSetsForAccessKeyID:accessKey secretAccessKey:secretKey error:error];
    if (backupSets == nil) {
        return NO;
    }
    for (BackupSet *backupSet in backupSets) {
        NSString *s3BucketName = [backupSet s3BucketName];
        NSString *computerUUID = [backupSet computerUUID];
        UserAndComputer *uac = [backupSet userAndComputer];
        printf("S3 bucket: %s", [s3BucketName UTF8String]);
        if (uac != nil) {
            printf("    %s (%s)", [[uac computerName] UTF8String], [[uac userName] UTF8String]);
        } else {
            printf("    (unknown computer)");
        }
        printf(" UUID %s", [computerUUID UTF8String]);
        NSString *computerBucketsPrefix = [NSString stringWithFormat:@"/%@/%@/buckets", s3BucketName, computerUUID];
        NSArray *s3BucketUUIDPaths = [s3 pathsWithPrefix:computerBucketsPrefix error:error];
        if (s3BucketUUIDPaths == nil) {
            return NO;
        }
        if ([s3BucketUUIDPaths count] == 0) {
            printf("    (no folders found)");
        }
        printf("\n");
        for (NSString *uuidPath in s3BucketUUIDPaths) {
            NSData *data = [s3 dataAtPath:uuidPath error:error];
            if (data == nil) {
                return NO;
            }
            DictNode *plist = [DictNode dictNodeWithXMLData:data error:error];
            if (plist == nil) {
                return NO;
            }
            printf("        %s\n", [[[plist stringNodeForKey:@"LocalPath"] stringValue] UTF8String]);
            printf("            UUID:            %s\n", [[uuidPath lastPathComponent] UTF8String]);
            printf("            restore command: arq_restore %s\n", [uuidPath UTF8String]);
        }
    }
    return YES;
}
- (BOOL)processPath:(NSError **)error {
    if (![self validateS3Keys:error]) {
        return NO;
    }
    if (encryptionPassword == nil) {
        SETNSERROR(@"ArqErrorDomain", -1, @"missing ARQ_ENCRYPTION_PASSWORD environment variable");
        return NO;
    }
    NSString *pattern = @"^/([^/]+)/([^/]+)/buckets/([^/]+)";
    NSRange s3BucketNameRange = [path rangeOfRegex:pattern capture:1];
    NSRange computerUUIDRange = [path rangeOfRegex:pattern capture:2];
    NSRange bucketUUIDRange = [path rangeOfRegex:pattern capture:3];
    if (s3BucketNameRange.location == NSNotFound || computerUUIDRange.location == NSNotFound || bucketUUIDRange.location == NSNotFound) {
        SETNSERROR(@"ArqErrorDomain", -1, @"invalid S3 path");
        return NO;
    }
    NSData *data = [s3 dataAtPath:path error:error];
    if (data == nil) {
        return NO;
    }
    DictNode *plist = [DictNode dictNodeWithXMLData:data error:error];
    if (plist == nil) {
        return NO;
    }
    NSString *s3BucketName = [path substringWithRange:s3BucketNameRange];
    NSString *computerUUID = [path substringWithRange:computerUUIDRange];
    NSString *bucketUUID = [path substringWithRange:bucketUUIDRange];
    NSString *bucketName = [[plist stringNodeForKey:@"BucketName"] stringValue];
    
    NSError *uacError = nil;
    NSData *uacData = [s3 dataAtPath:[NSString stringWithFormat:@"/%@/%@/computerinfo", s3BucketName, computerUUID] error:&uacError];
    UserAndComputer *uac = nil;
    if (uacData != nil) {
        uac = [[[UserAndComputer alloc] initWithXMLData:uacData error:&uacError] autorelease];
    }
    
    NSError *saltError = nil;
    ArqSalt *arqSalt = [[[ArqSalt alloc] initWithAccessKeyID:accessKey secretAccessKey:secretKey s3BucketName:s3BucketName computerUUID:computerUUID] autorelease];
    NSData *salt = [arqSalt salt:&saltError];
    if (salt == nil) {
        if ([saltError code] != ERROR_NOT_FOUND) {
            if (error != NULL) {
                *error = saltError;
            }
            return NO;
        }
    }
    ArqRepo *repo = [[[ArqRepo alloc] initWithS3Service:s3 s3BucketName:s3BucketName computerUUID:computerUUID bucketUUID:bucketUUID encryptionPassword:encryptionPassword salt:salt error:error] autorelease];
    if (repo == nil) {
        return NO;
    }
    
    if ([commitSHA1 isEqualToString:@"reflog"]) {
        printf("printing reflog for %s\n", [bucketName UTF8String]);
        ReflogPrinter *printer = [[[ReflogPrinter alloc] initWithS3BucketName:s3BucketName computerUUID:computerUUID bucketUUID:bucketUUID s3:s3 repo:repo] autorelease];
        if (![printer printReflog:error]) {
            return NO;
        }
    } else {
        printf("restoring %s from ", [bucketName UTF8String]);    
        if (uac != nil) {
            printf("%s (%s)", [[uac computerName] UTF8String], [[uac userName] UTF8String]);
        } else {
            printf("(unknown computer)");
        }
        printf(" to %s/%s\n", [[[NSFileManager defaultManager] currentDirectoryPath] UTF8String], [bucketName UTF8String]);
        
        Restorer *restorer = [[[Restorer alloc] initWithRepo:repo bucketName:bucketName commitSHA1:commitSHA1] autorelease];
        if (![restorer restore:error]) {
            return NO;
        }
        printf("restored files are in %s\n", [bucketName fileSystemRepresentation]);
    }
    return YES;
}
- (BOOL)validateS3Keys:(NSError **)error {
    if (accessKey == nil) {
        SETNSERROR(@"ArqErrorDomain", -1, @"missing ARQ_ACCESS_KEY environment variable");
        return NO;
    }
    if (secretKey == nil) {
        SETNSERROR(@"ArqErrorDomain", -1, @"missing ARQ_SECRET_KEY environment variable");
        return NO;
    }
    return YES;
}
@end
