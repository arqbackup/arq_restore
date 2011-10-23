/*
 Copyright (c) 2010, Stefan Reitshamer http://www.haystacksoftware.com
 
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

#import "BackupSet.h"
#import "S3AuthorizationProvider.h"
#import "S3Service.h"
#import "UserAndComputer.h"
#import "NSErrorCodes.h"
#import "NSData-Encrypt.h"
#import "CryptoKey.h"
#import "RegexKitLite.h"
#import "ArqRepo.h"
#import "BlobKey.h"
#import "SetNSError.h"
#import "Commit.h"
#import "S3ObjectMetadata.h"
#import "ArqSalt.h"

@implementation BackupSet
+ (NSArray *)allBackupSetsForAccessKeyID:(NSString *)theAccessKeyID secretAccessKey:(NSString *)theSecretAccessKey error:(NSError **)error {
    S3AuthorizationProvider *sap = [[[S3AuthorizationProvider alloc] initWithAccessKey:theAccessKeyID secretKey:theSecretAccessKey] autorelease];
    S3Service *s3 = [[[S3Service alloc] initWithS3AuthorizationProvider:sap useSSL:YES retryOnTransientError:NO] autorelease];
    NSArray *s3BucketNames = [s3 s3BucketNames:error];
    if (s3BucketNames == nil) {
        return nil;
    }
    NSMutableArray *ret = [NSMutableArray array];
    for (NSString *theS3BucketName in s3BucketNames) {
        if ([theS3BucketName rangeOfString:@"-com-haystacksoftware-arq"].location == NSNotFound
            && [theS3BucketName rangeOfString:@".com.haystacksoftware.arq"].location == NSNotFound) {
            HSLogDebug(@"skipping bucket %@", theS3BucketName);
        } else {
            NSString *queryPrefix = [NSString stringWithFormat:@"/%@/", [theS3BucketName lowercaseString]];
            NSArray *theS3ComputerUUIDs = [s3 commonPrefixesForPathPrefix:queryPrefix delimiter:@"/" error:error];
            if (theS3ComputerUUIDs == nil) {
                return nil;
            }
            for (NSString *s3ComputerUUID in theS3ComputerUUIDs) {
                NSString *computerInfoPath = [NSString stringWithFormat:@"/%@/%@/computerinfo", theS3BucketName, s3ComputerUUID];
                NSError *uacError = nil;
                NSData *uacData = [s3 dataAtPath:computerInfoPath error:&uacError];
                UserAndComputer *uac = nil;
                if (uacData != nil) {
                    uac = [[[UserAndComputer alloc] initWithXMLData:uacData error:&uacError] autorelease];
                    if (uac == nil) {
                        HSLogError(@"error parsing UserAndComputer data: %@", uacError);
                    }
                }
                BackupSet *backupSet = [[[BackupSet alloc] initWithAccessKeyID:theAccessKeyID
                                                               secretAccessKey:theSecretAccessKey 
                                                                  s3BucketName:theS3BucketName 
                                                                  computerUUID:s3ComputerUUID 
                                                               userAndComputer:uac] autorelease];
                [ret addObject:backupSet];
            }
        }
    }
    NSSortDescriptor *descriptor = [[[NSSortDescriptor alloc] initWithKey:@"description" ascending:YES] autorelease];
    [ret sortUsingDescriptors:[NSArray arrayWithObject:descriptor]];
    return ret;
}

- (id)initWithAccessKeyID:(NSString *)theAccessKeyID 
          secretAccessKey:(NSString *)theSecretAccessKey
             s3BucketName:(NSString *)theS3BucketName 
             computerUUID:(NSString *)theComputerUUID 
          userAndComputer:(UserAndComputer *)theUAC {
    if (self = [super init]) {
        accessKeyID = [theAccessKeyID retain];
        secretAccessKey = [theSecretAccessKey retain];
        s3BucketName = [theS3BucketName retain];
        computerUUID = [theComputerUUID retain];
        uac = [theUAC retain];
    }
    return self;
}
- (void)dealloc {
    [accessKeyID release];
    [secretAccessKey release];
    [s3BucketName release];
    [computerUUID release];
    [uac release];
    [super dealloc];
}
- (NSString *)s3BucketName {
    return s3BucketName;
}
- (NSString *)computerUUID {
    return computerUUID;
}
- (UserAndComputer *)userAndComputer {
    return uac;
}


#pragma mark NSObject
- (NSString *)description {
    NSString *bucketRegion = [S3Service displayNameForBucketRegion:[S3Service s3BucketRegionForS3BucketName:s3BucketName]];
    if (uac != nil) {
        return [NSString stringWithFormat:@"%@ (%@) : %@ (%@)", [uac computerName], [uac userName], bucketRegion, computerUUID];
    }
    return [NSString stringWithFormat:@"unknown computer : %@ (%@)", bucketRegion, computerUUID];
    
}
@end
