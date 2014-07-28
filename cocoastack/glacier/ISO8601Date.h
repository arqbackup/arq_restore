//
//  ISO8601Date.h
//  Arq
//
//  Created by Stefan Reitshamer on 9/7/12.
//
//


@interface ISO8601Date : NSObject {
    
}
+ (NSString *)errorDomain;
+ (NSDate *)dateFromString:(NSString *)str error:(NSError **)error;
+ (NSString *)basicDateTimeStringFromDate:(NSDate *)theDate;
+ (NSString *)basicDateStringFromDate:(NSDate *)theDate;
@end
