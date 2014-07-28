//
//  SFTPTargetConnection.h
//  Arq
//
//  Created by Stefan Reitshamer on 4/21/14.
//  Copyright (c) 2014 Stefan Reitshamer. All rights reserved.
//

#import "TargetConnection.h"
@class SFTPRemoteFS;
@class BaseTargetConnection;
@class Target;


@interface SFTPTargetConnection : NSObject <TargetConnection> {
    SFTPRemoteFS *sftpRemoteFS;
    BaseTargetConnection *base;
}
- (id)initWithTarget:(Target *)theTarget;

@end
