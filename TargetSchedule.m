/*
 Copyright (c) 2009-2014, Stefan Reitshamer http://www.haystacksoftware.com
 
 All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 
 * Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in the
 documentation and/or other materials provided with the distribution.
 
 * Neither the names of PhotoMinds LLC or Haystack Software, nor the names of
 their contributors may be used to endorse or promote products derived from
 this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
 TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */


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
