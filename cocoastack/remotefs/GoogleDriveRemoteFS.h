//
//  GoogleDriveRemoteFS.h
//  Arq
//
//  Created by Stefan Reitshamer on 7/16/14.
//  Copyright (c) 2014 Stefan Reitshamer. All rights reserved.
//

#import "RemoteFS.h"
@class Target;
@class GoogleDrive;


@interface GoogleDriveRemoteFS : NSObject <RemoteFS> {
    Target *target;
    GoogleDrive *googleDrive;
}
- (id)initWithTarget:(Target *)theTarget;

@end
