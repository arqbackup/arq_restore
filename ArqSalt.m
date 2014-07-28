//
//  Created by Stefan Reitshamer on 7/16/11.
//  Copyright 2011 Haystack Software. All rights reserved.
//

#import "ArqSalt.h"
#import "NSFileManager_extra.h"
#import "UserLibrary_Arq.h"
#import "Target.h"
#import "TargetConnection.h"
#import "Streams.h"


#define SALT_LENGTH (8)


@implementation ArqSalt
- (id)initWithTarget:(Target *)theTarget
           targetUID:(uid_t)theTargetUID
           targetGID:(gid_t)theTargetGID
        computerUUID:(NSString *)theComputerUUID {
    if (self = [super init]) {
        target = [theTarget retain];
        uid = theTargetUID;
        gid = theTargetGID;
        computerUUID = [theComputerUUID retain];
    }
    return self;
}
- (void)dealloc {
    [target release];
    [computerUUID release];
    [super dealloc];
}

- (NSData *)saltWithTargetConnectionDelegate:(id<TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    NSData *ret = [NSData dataWithContentsOfFile:[self localPath] options:NSUncachedRead error:error];
    if (ret == nil) {
        id <TargetConnection> targetConnection = [target newConnection];
        do {
            ret = [targetConnection saltDataForComputerUUID:computerUUID delegate:theDelegate error:error];
            if (ret != nil) {
                NSError *myError = nil;
                if (![[NSFileManager defaultManager] ensureParentPathExistsForPath:[self localPath] targetUID:uid targetGID:gid error:&myError]
                    || ![Streams writeData:ret atomicallyToFile:[self localPath] targetUID:uid targetGID:gid bytesWritten:NULL error:&myError]) {
                    HSLogError(@"error caching salt data to %@: %@", [self localPath], myError);
                }
            }
        } while(0);
        [targetConnection release];
    }
    return ret;
}
- (BOOL)saveSalt:(NSData *)theSalt targetConnectionDelegate:(id<TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    id <TargetConnection> targetConnection = [target newConnection];
    BOOL ret = YES;
    do {
        ret = [targetConnection setSaltData:theSalt forComputerUUID:computerUUID delegate:theDelegate error:error]
        && [[NSFileManager defaultManager] ensureParentPathExistsForPath:[self localPath] targetUID:uid targetGID:gid error:error]
        && [Streams writeData:theSalt atomicallyToFile:[self localPath] targetUID:uid targetGID:gid bytesWritten:NULL error:error];
    } while (0);
    [targetConnection release];
    return ret;
}
- (NSData *)createSaltWithTargetConnectionDelegate:(id<TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    NSData *theSalt = [self createRandomSalt];
    if (![self saveSalt:theSalt targetConnectionDelegate:theDelegate error:error]) {
        return nil;
    }
    return theSalt;
}
            

#pragma mark internal
- (NSData *)createRandomSalt {
    unsigned char buf[SALT_LENGTH];
    for (NSUInteger i = 0; i < SALT_LENGTH; i++) {
        buf[i] = (unsigned char)(rand() % 256);
    }
    return [[[NSData alloc] initWithBytes:buf length:SALT_LENGTH] autorelease];
}
- (NSString *)localPath {
    return [NSString stringWithFormat:@"%@/Cache.noindex/%@/%@/salt.dat", [UserLibrary arqUserLibraryPath], [target targetUUID], computerUUID];
}
@end
