//
//  TargetSchedule.m
//  Arq
//
//  Created by Stefan Reitshamer on 12/10/13.
//  Copyright (c) 2013 Stefan Reitshamer. All rights reserved.
//

#import "TargetSchedule.h"
#import "DictNode.h"
#import "IntegerNode.h"
#import "IntegerIO.h"
#import "BufferedOutputStream.h"
#import "BooleanNode.h"
#import "BooleanIO.h"


#define TARGET_DATA_VERSION (1)


@implementation TargetSchedule
- (id)initWithScheduleType:(TargetScheduleType)theType
             numberOfHours:(int)theNumberOfHours
          minutesAfterHour:(int)theMinutesAfterHour
                backupHour:(int)theBackupHour
budgetEnforcementIntervalHours:(int)theBudgetEnforcementIntervalHours
         pauseDuringWindow:(BOOL)thePauseDuringWindow
             pauseFromHour:(NSUInteger)thePauseFromHour
               pauseToHour:(NSUInteger)thePauseToHour {
    if (self = [super init]) {
        type = theType;
        numberOfHours = theNumberOfHours;
        minutesAfterHour = theMinutesAfterHour;
        backupHour = theBackupHour;
        budgetEnforcementIntervalHours = theBudgetEnforcementIntervalHours;
        pauseDuringWindow = thePauseDuringWindow;
        pauseFromHour = (uint32_t)thePauseFromHour;
        pauseToHour = (uint32_t)thePauseToHour;
    }
    return self;
}
- (id)initWithPlist:(DictNode *)thePlist {
    if (self = [super init]) {
        type = [[thePlist integerNodeForKey:@"type"] intValue];
        numberOfHours = [[thePlist integerNodeForKey:@"numberOfHours"] intValue];
        minutesAfterHour = [[thePlist integerNodeForKey:@"minutesAfterHour"] intValue];
        backupHour = [[thePlist integerNodeForKey:@"backupHour"] intValue];
        budgetEnforcementIntervalHours = [[thePlist integerNodeForKey:@"budgetEnforcementIntervalHours"] intValue];
        pauseDuringWindow = [[thePlist booleanNodeForKey:@"pauseDuringWindow"] booleanValue];
        pauseFromHour = [[thePlist integerNodeForKey:@"pauseFromHour"] intValue];
        pauseToHour = [[thePlist integerNodeForKey:@"pauseToHour"] intValue];
    }
    return self;
}
- (id)initWithBufferedInputStream:(BufferedInputStream *)theBIS error:(NSError **)error {
    if (self = [super init]) {
        uint32_t version = 0;
        if (![IntegerIO readUInt32:&version from:theBIS error:error]
            || ![IntegerIO readUInt32:&type from:theBIS error:error]
            || ![IntegerIO readUInt32:&numberOfHours from:theBIS error:error]
            || ![IntegerIO readUInt32:&minutesAfterHour from:theBIS error:error]
            || ![IntegerIO readUInt32:&backupHour from:theBIS error:error]
            || ![IntegerIO readUInt32:&budgetEnforcementIntervalHours from:theBIS error:error]
            || ![BooleanIO read:&pauseDuringWindow from:theBIS error:error]
            || ![IntegerIO readUInt32:&pauseFromHour from:theBIS error:error]
            || ![IntegerIO readUInt32:&pauseToHour from:theBIS error:error]) {
            [self release];
            return nil;
        }
    }
    return self;
}

- (TargetScheduleType)type {
    return type;
}
- (uint32_t)numberOfHours {
    return numberOfHours;
}
- (uint32_t)minutesAfterHour {
    return minutesAfterHour;
}
- (uint32_t)backupHour {
    return backupHour;
}
- (uint32_t)budgetEnforcementIntervalHours {
    return budgetEnforcementIntervalHours;
}
- (BOOL)pauseDuringWindow {
    return pauseDuringWindow;
}
- (uint32_t)pauseFromHour {
    return pauseFromHour;
}
- (uint32_t)pauseToHour {
    return pauseToHour;
}
- (DictNode *)toPlist {
    DictNode *ret = [[[DictNode alloc] init] autorelease];
    [ret putInt:TARGET_DATA_VERSION forKey:@"dataVersion"];
    [ret putInt:type forKey:@"type"];
    [ret putInt:numberOfHours forKey:@"numberOfHours"];
    [ret putInt:minutesAfterHour forKey:@"minutesAfterHour"];
    [ret putInt:backupHour forKey:@"backupHour"];
    [ret putInt:budgetEnforcementIntervalHours forKey:@"budgetEnforcementIntervalHours"];
    [ret putBoolean:pauseDuringWindow forKey:@"pauseDuringWindow"];
    [ret putInt:pauseFromHour forKey:@"pauseFromHour"];
    [ret putInt:pauseToHour forKey:@"pauseToHour"];
    return ret;
}
- (BOOL)writeTo:(BufferedOutputStream *)theBOS error:(NSError **)error {
    return [IntegerIO writeUInt32:TARGET_DATA_VERSION to:theBOS error:error]
    && [IntegerIO writeUInt32:type to:theBOS error:error]
    && [IntegerIO writeUInt32:numberOfHours to:theBOS error:error]
    && [IntegerIO writeUInt32:minutesAfterHour to:theBOS error:error]
    && [IntegerIO writeUInt32:backupHour to:theBOS error:error]
    && [IntegerIO writeUInt32:budgetEnforcementIntervalHours to:theBOS error:error]
    && [BooleanIO write:pauseDuringWindow to:theBOS error:error]
    && [IntegerIO writeUInt32:pauseFromHour to:theBOS error:error]
    && [IntegerIO writeUInt32:pauseToHour to:theBOS error:error];
}
@end
