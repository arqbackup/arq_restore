/*
 Copyright (c) 2009-2026, Haystack Software LLC https://www.arqbackup.com
 
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

#import "RFC822.h"

#import "S3Service.h"

#define FMT822 (@"^(\\d{4})-(\\d{2})-(\\d{2})T(\\d{2}):(\\d{2}):(\\d{2})\\.(\\d+)Z$")

@implementation RFC822
+ (NSDate *)dateFromString:(NSString *)dateString error:(NSError **)error {
    NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:FMT822 options:0 error:nil];
    NSTextCheckingResult *match = [re firstMatchInString:dateString options:0 range:NSMakeRange(0, dateString.length)];
    if (match == nil) {
        SETNSERROR([S3Service errorDomain], S3SERVICE_INVALID_PARAMETERS, @"invalid RFC822 date '%@'", dateString);
        return nil;
    }
    return [NSCalendarDate dateWithYear:[[dateString substringWithRange:[match rangeAtIndex:1]] intValue]
                                  month:[[dateString substringWithRange:[match rangeAtIndex:2]] intValue]
                                    day:[[dateString substringWithRange:[match rangeAtIndex:3]] intValue]
                                   hour:[[dateString substringWithRange:[match rangeAtIndex:4]] intValue]
                                 minute:[[dateString substringWithRange:[match rangeAtIndex:5]] intValue]
                                 second:[[dateString substringWithRange:[match rangeAtIndex:6]] intValue]
                               timeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
}
@end
