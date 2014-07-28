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

#import "ISO8601Date.h"
#import "RegexKitLite.h"


#define FMT822 (@"^(\\d{4})-(\\d{2})-(\\d{2})T(\\d{2}):(\\d{2}):(\\d{2})\\.(\\d+)Z$")


@implementation ISO8601Date
+ (NSString *)errorDomain {
    return @"ISO8601DateErrorDomain";
}
+ (NSDate *)dateFromString:(NSString *)str error:(NSError **)error {
    if ([str rangeOfRegex:FMT822].location == NSNotFound) {
        SETNSERROR([ISO8601Date errorDomain], -1, @"invalid ISO8601 date '%@'", str);
        return nil;
    }
    return [NSCalendarDate dateWithYear:[[str stringByMatching:FMT822 capture:1] intValue]
                                  month:[[str stringByMatching:FMT822 capture:2] intValue]
                                    day:[[str stringByMatching:FMT822 capture:3] intValue]
                                   hour:[[str stringByMatching:FMT822 capture:4] intValue]
                                 minute:[[str stringByMatching:FMT822 capture:5] intValue]
                                 second:[[str stringByMatching:FMT822 capture:6] intValue]
                               timeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
    
    
}
+ (NSString *)basicDateTimeStringFromDate:(NSDate *)theDate {
    NSDateFormatter *formatter = [[[NSDateFormatter alloc] init] autorelease];
    [formatter setDateFormat:@"yyyyMMdd'T'HHmmss'Z'"];
    [formatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
    NSCalendar *gregorianCalendar = [[[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar] autorelease];
    [formatter setCalendar:gregorianCalendar];
    return [formatter stringFromDate:theDate];
}
+ (NSString *)basicDateStringFromDate:(NSDate *)theDate {
    NSDateFormatter *formatter = [[[NSDateFormatter alloc] init] autorelease];
    [formatter setDateFormat:@"yyyyMMdd"];
    [formatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
    NSCalendar *gregorianCalendar = [[[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar] autorelease];
    [formatter setCalendar:gregorianCalendar];
    return [formatter stringFromDate:theDate];
}
@end
