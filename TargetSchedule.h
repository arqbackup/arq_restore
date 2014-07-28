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
