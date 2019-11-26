/*
 Copyright (c) 2009-2017, Haystack Software LLC https://www.arqbackup.com
 
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
#import "GlacierAuthorizationProvider.h"
#import "GlacierService.h"
#import "UserAndComputer.h"
#import "CryptoKey.h"
#import "RegexKitLite.h"
#import "BlobKey.h"
#import "Commit.h"
#import "S3ObjectMetadata.h"
#import "AWSRegion.h"
#import "Bucket.h"
#import "Target.h"
#import "TargetConnection.h"
#import "Repo.h"
#import "UserLibrary_Arq.h"
#import "NSString+SBJSON.h"


@implementation BackupSet
+ (NSArray *)allBackupSetsForTarget:(Target *)theTarget targetConnectionDelegate:(id <TargetConnectionDelegate>)theDelegate activityListener:(id<BackupSetActivityListener>)theActivityListener error:(NSError **)error {
    TargetConnection *targetConnection = [theTarget newConnection:error];
    if (targetConnection == nil) {
        return nil;
    }
    NSArray *ret = [BackupSet allBackupSetsForTarget:theTarget targetConnection:targetConnection targetConnectionDelegate:theDelegate activityListener:theActivityListener error:error];
    [targetConnection release];
    return ret;
}
+ (NSArray *)allBackupSetsForTarget:(Target *)theTarget targetConnection:(TargetConnection *)targetConnection targetConnectionDelegate:(id <TargetConnectionDelegate>)theDelegate activityListener:(id<BackupSetActivityListener>)theActivityListener error:(NSError **)error {
    NSArray *theComputerUUIDs = [targetConnection computerUUIDsWithDelegate:theDelegate error:error];
    if (theComputerUUIDs == nil) {
        return nil;
    }

    NSMutableArray *ret = [NSMutableArray array];
    for (NSUInteger i = 0; i < [theComputerUUIDs count]; i++) {
        [theActivityListener backupSetActivity:[NSString stringWithFormat:@"Loading backup set %ld of %ld at %@", i+1, [theComputerUUIDs count], [theTarget description]]];

        NSString *theComputerUUID = [theComputerUUIDs objectAtIndex:i];
        NSError *uacError = nil;
        UserAndComputer *uac = nil;
        NSData *uacData = [targetConnection computerInfoForComputerUUID:theComputerUUID delegate:theDelegate error:&uacError];
        if (uacData == nil) {
            HSLogWarn(@"unable to read %@ (skipping): %@", theComputerUUID, [uacError localizedDescription]);
        } else {
            uac = [[[UserAndComputer alloc] initWithXMLData:uacData error:&uacError] autorelease];
            if (uac == nil) {
                HSLogError(@"error parsing UserAndComputer data %@: %@", theComputerUUID, uacError);
            }
        }
        BackupSet *backupSet = [[[BackupSet alloc] initWithTarget:theTarget
                                                     computerUUID:theComputerUUID
                                                  userAndComputer:uac] autorelease];
        [ret addObject:backupSet];
    }
    NSSortDescriptor *descriptor = [[[NSSortDescriptor alloc] initWithKey:@"description" ascending:YES] autorelease];
    [ret sortUsingDescriptors:[NSArray arrayWithObject:descriptor]];
    return ret;
}

- (id)initWithTarget:(Target *)theTarget
        computerUUID:(NSString *)theComputerUUID
     userAndComputer:(UserAndComputer *)theUAC {
    if (self = [super init]) {
        target = [theTarget retain];
        computerUUID = [theComputerUUID retain];
        uac = [theUAC retain];
    }
    return self;
}
- (void)dealloc {
    [target release];
    [computerUUID release];
    [uac release];
    [super dealloc];
}
- (NSString *)errorDomain {
    return @"BackupSetErrorDomain";
}
- (Target *)target {
    return target;
}
- (NSString *)computerUUID {
    return computerUUID;
}
- (UserAndComputer *)userAndComputer {
    return uac;
}


#pragma mark NSObject
- (NSString *)description {
    if (uac != nil) {
        return [NSString stringWithFormat:@"%@ : %@ (%@)", [uac computerName], [uac userName], computerUUID];
    }
    return [NSString stringWithFormat:@"unknown computer : %@", computerUUID];
    
}
@end
