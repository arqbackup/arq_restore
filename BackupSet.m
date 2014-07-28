//
//  BackupSet.m
//  Arq
//
//  Created by Stefan Reitshamer on 4/11/11.
//  Copyright 2011 Haystack Software. All rights reserved.
//

#import "BackupSet.h"
#import "S3AuthorizationProvider.h"
#import "S3Service.h"
#import "GlacierAuthorizationProvider.h"
#import "GlacierService.h"
#import "UserAndComputer.h"
#import "S3DeleteReceiver.h"
#import "CryptoKey.h"
#import "RegexKitLite.h"
#import "BlobKey.h"
#import "Commit.h"
#import "S3ObjectMetadata.h"
#import "ArqSalt.h"
#import "AWSRegion.h"
#import "Bucket.h"
#import "Target.h"
#import "TargetConnection.h"
#import "Repo.h"


@implementation BackupSet
+ (NSArray *)allBackupSetsForTarget:(Target *)theTarget targetConnectionDelegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    id <TargetConnection> targetConnection = [[theTarget newConnection] autorelease];
    NSArray *theComputerUUIDs = [targetConnection computerUUIDsWithDelegate:theDelegate error:error];
    if (theComputerUUIDs == nil) {
        return nil;
    }
    
    NSMutableArray *ret = [NSMutableArray array];
    for (NSString *theComputerUUID in theComputerUUIDs) {
        NSError *uacError = nil;
        NSData *uacData = [targetConnection computerInfoForComputerUUID:theComputerUUID delegate:theDelegate error:&uacError];
        if (uacData == nil) {
            HSLogWarn(@"unable to read %@ (skipping): %@", theComputerUUID, [uacError localizedDescription]);
        } else {
            UserAndComputer *uac = [[[UserAndComputer alloc] initWithXMLData:uacData error:&uacError] autorelease];
            if (uac == nil) {
                HSLogError(@"error parsing UserAndComputer data %@: %@", theComputerUUID, uacError);
            } else {
                BackupSet *backupSet = [[[BackupSet alloc] initWithTarget:theTarget
                                                             computerUUID:theComputerUUID
                                                          userAndComputer:uac] autorelease];
                [ret addObject:backupSet];
            }
        }
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
