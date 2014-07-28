//
//  TargetSchedule.h
//  Arq
//
//  Created by Stefan Reitshamer on 12/10/13.
//  Copyright (c) 2013 Stefan Reitshamer. All rights reserved.
//

enum {
    TargetScheduleTypeHourly = 0,
    TargetScheduleTypeDaily = 1,
    TargetScheduleTypeManual = 2
};
typedef uint32_t TargetScheduleType;


@class DictNode;
@class BufferedInputStream;
@class BufferedOutputStream;

@interface TargetSchedule : NSObject {
    TargetScheduleType type;
    uint32_t numberOfHours;
    uint32_t minutesAfterHour;
    uint32_t backupHour;
    uint32_t budgetEnforcementIntervalHours;
    BOOL pauseDuringWindow;
    uint32_t pauseFromHour;
    uint32_t pauseToHour;
}
- (id)initWithScheduleType:(TargetScheduleType)theType
             numberOfHours:(int)theNumberOfHours
          minutesAfterHour:(int)theMinutesAfterHour
                backupHour:(int)theBackupHour
budgetEnforcementIntervalHours:(int)theBudgetEnforcementIntervalHours
         pauseDuringWindow:(BOOL)thePauseDuringWindow
             pauseFromHour:(NSUInteger)thePauseFromHour
               pauseToHour:(NSUInteger)thePauseToHour;
- (id)initWithPlist:(DictNode *)thePlist;
- (id)initWithBufferedInputStream:(BufferedInputStream *)theBIS error:(NSError **)error;

- (TargetScheduleType)type;
- (uint32_t)numberOfHours;
- (uint32_t)minutesAfterHour;
- (uint32_t)backupHour;
- (uint32_t)budgetEnforcementIntervalHours;
- (BOOL)pauseDuringWindow;
- (uint32_t)pauseFromHour;
- (uint32_t)pauseToHour;
- (DictNode *)toPlist;
- (BOOL)writeTo:(BufferedOutputStream *)theBOS error:(NSError **)error;

@end
