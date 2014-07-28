//
//  GoogleDriveTargetConnection.h
//  Arq
//
//  Created by Stefan Reitshamer on 7/18/14.
//  Copyright (c) 2014 Stefan Reitshamer. All rights reserved.
//

#import "TargetConnection.h"
@class BaseTargetConnection;
@class Target;
@class GoogleDriveRemoteFS;


@interface GoogleDriveTargetConnection : NSObject <TargetConnection> {
    GoogleDriveRemoteFS *googleDriveRemoteFS;
    BaseTargetConnection *base;
}

- (id)initWithTarget:(Target *)theTarget;

@end
