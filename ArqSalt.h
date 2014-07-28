//
//  Created by Stefan Reitshamer on 7/16/11.
//  Copyright 2011 Haystack Software. All rights reserved.
//

#import "TargetConnection.h"
@class AWSRegion;
@class Target;


@interface ArqSalt : NSObject {
    Target *target;
    uid_t uid;
    gid_t gid;
    NSString *computerUUID;
}
- (id)initWithTarget:(Target *)theTarget
           targetUID:(uid_t)theTargetUID
           targetGID:(gid_t)theTargetGID
        computerUUID:(NSString *)theComputerUUID;
- (NSData *)saltWithTargetConnectionDelegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error;
- (BOOL)saveSalt:(NSData *)theSalt targetConnectionDelegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error;
- (NSData *)createSaltWithTargetConnectionDelegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error;
@end
