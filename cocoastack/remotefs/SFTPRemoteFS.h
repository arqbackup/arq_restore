//
//  SFTPRemoteFS.h
//  Arq
//
//  Created by Stefan Reitshamer on 3/18/14.
//  Copyright (c) 2014 Stefan Reitshamer. All rights reserved.
//

#import "RemoteFS.h"
@class Target;
@class SFTPServer;
@protocol TargetConnectionDelegate;


@interface SFTPRemoteFS : NSObject <RemoteFS> {
    Target *target;
    
    NSString *tempDir;
    SFTPServer *sftpServer;
    NSTimeInterval sleepTime;
}

- (id)initWithTarget:(Target *)theTarget tempDir:(NSString *)theTempDir;

- (BOOL)renameObjectAtPath:(NSString *)theSource toPath:(NSString *)theDest targetConnectionDelegate:(id <TargetConnectionDelegate>)theTargetConnectionDelegate error:(NSError **)error;
@end
