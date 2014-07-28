//
//  S3TargetConnection.h
//  Arq
//
//  Created by Stefan Reitshamer on 4/21/14.
//  Copyright (c) 2014 Stefan Reitshamer. All rights reserved.
//

#import "TargetConnection.h"
@class BaseTargetConnection;
@class Target;
@class S3RemoteFS;


@interface S3TargetConnection : NSObject <TargetConnection> {
    S3RemoteFS *s3RemoteFS;
    BaseTargetConnection *base;
}
- (id)initWithTarget:(Target *)theTarget;

@end
