//
//  ISO8601Date.m
//  Arq
//
//  Created by Stefan Reitshamer on 9/7/12.
//
//

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
