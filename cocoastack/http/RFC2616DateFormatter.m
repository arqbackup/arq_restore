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


#import "RFC2616DateFormatter.h"


@implementation RFC2616DateFormatter
- (id)init {
    if (self = [super init]) {
        formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"EEE, dd MMM yyyy HH:mm:ss"];
        [formatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
        usLocale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US"];
        if (usLocale != nil) {
            [formatter setLocale:usLocale];
        } else {
            HSLogWarn(@"no en_US locale installed");
        }
    }
    return self;
}
- (void)dealloc {
    [formatter release];
    [usLocale release];
    [super dealloc];
}
- (NSString *)rfc2616StringFromDate:(NSDate *)date {
    //FIXME: If US locale isn't available, put the English words into the date yourself, according to http://www.ietf.org/rfc/rfc2616.txt
    
    // We append " GMT" here instead of using a "z" in the format string because on 10.9 the "z" produces "GMT", but on 10.7 it produces "GMT+00:00" which makes Google Cloud Storage return a "MalformedHeaderValue" error.
    return [[formatter stringFromDate:date] stringByAppendingString:@" GMT"];
}
@end
