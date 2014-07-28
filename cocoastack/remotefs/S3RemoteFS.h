//
//  S3RemoteFS.h
//  Arq
//
//  Created by Stefan Reitshamer on 3/18/14.
//  Copyright (c) 2014 Stefan Reitshamer. All rights reserved.
//

#import "RemoteFS.h"
@class Target;
@class S3Service;


@interface S3RemoteFS : NSObject <RemoteFS> {
    Target *target;
    S3Service *s3;
}

- (id)initWithTarget:(Target *)theTarget;
@end
