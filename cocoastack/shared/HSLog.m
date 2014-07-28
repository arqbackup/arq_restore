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


#import "HSLog.h"

unsigned int global_hslog_level = HSLOG_LEVEL_ERROR;

void setHSLogLevel(int level) {
    if (global_hslog_level != level) {
        global_hslog_level = level;
        NSLog(@"set log level to %@", nameForHSLogLevel(level));
    }
}
extern int hsLogLevelForName(NSString *levelName) {
    if ([[levelName lowercaseString] isEqualToString:@"error"]) {
        return HSLOG_LEVEL_ERROR;
    } else if ([[levelName lowercaseString] isEqualToString:@"warn"]) {
        return HSLOG_LEVEL_WARN;
    } else if ([[levelName lowercaseString] isEqualToString:@"info"]) {
        return HSLOG_LEVEL_INFO;
    } else if ([[levelName lowercaseString] isEqualToString:@"detail"]) {
        return HSLOG_LEVEL_DETAIL;
    } else if ([[levelName lowercaseString] isEqualToString:@"debug"]) {
        return HSLOG_LEVEL_DEBUG;
    } else if ([[levelName lowercaseString] isEqualToString:@"trace"]) {
        return HSLOG_LEVEL_TRACE;
    }
    return HSLOG_LEVEL_NONE;
}
extern NSString *nameForHSLogLevel(int level) {
    switch (level) {
        case HSLOG_LEVEL_ERROR:
            return @"Error";
        case HSLOG_LEVEL_WARN:
            return @"Warn";
        case HSLOG_LEVEL_INFO:
            return @"Info";
        case HSLOG_LEVEL_DETAIL:
            return @"Detail";
        case HSLOG_LEVEL_DEBUG:
            return @"Debug";
        case HSLOG_LEVEL_TRACE:
            return @"Trace";
    }
    return @"none";
}
