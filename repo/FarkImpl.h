//
//  Fark.h
//  Arq
//
//  Created by Stefan Reitshamer on 12/30/13.
//  Copyright (c) 2013 Stefan Reitshamer. All rights reserved.
//

#import "TargetConnection.h"
#import "Fark.h"
@class Target;
@protocol TargetConnection;
@class BlobKey;
@class PackId;


@interface FarkImpl : NSObject <Fark> {
    Target *target;
    id <TargetConnection> targetConnection;
    NSString *computerUUID;
    id <TargetConnectionDelegate> targetConnectionDelegate;
    uid_t uid;
    gid_t gid;
    
    NSMutableSet *packIdsAlreadyPostedForRestore;
    NSMutableSet *downloadablePackIds;
}
- (id)initWithTarget:(Target *)theTarget
        computerUUID:(NSString *)theComputerUUID
targetConnectionDelegate:(id <TargetConnectionDelegate>)theTargetConnectionDelegate
           targetUID:(uid_t)theTargetUID
           targetGID:(gid_t)theTargetGID;

@end
