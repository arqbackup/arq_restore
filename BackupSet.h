//
//  BackupSet.h
//  Arq
//
//  Created by Stefan Reitshamer on 4/11/11.
//  Copyright 2011 Haystack Software. All rights reserved.
//


@class UserAndComputer;
@class AppConfig;
@class Target;
@protocol TargetConnectionDelegate;


@interface BackupSet : NSObject {
    Target *target;
    NSString *computerUUID;
    UserAndComputer *uac;
}
+ (NSArray *)allBackupSetsForTarget:(Target *)theTarget targetConnectionDelegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error;

- (id)initWithTarget:(Target *)theTarget
        computerUUID:(NSString *)theComputerUUID
     userAndComputer:(UserAndComputer *)theUAC;
- (NSString *)errorDomain;
- (Target *)target;
- (NSString *)computerUUID;
- (UserAndComputer *)userAndComputer;
@end
