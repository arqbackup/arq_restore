/*
 Copyright (c) 2009-2017, Haystack Software LLC https://www.arqbackup.com
 
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



#include <sys/stat.h>
#import "HSLog.h"
#import "System.h"
#import "NSFileManager_extra.h"
#import "HSLogFileManager.h"


int global_hslog_level = -1;

DDLogLevel ddLogLevel = DDLogLevelInfo;


@implementation HSLog
CWL_SYNTHESIZE_SINGLETON_FOR_CLASS(HSLog)

+ (int)hsLogLevelForName:(NSString *)levelName {
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
    }
    return HSLOG_LEVEL_NONE;
}
+ (NSString *)nameForHSLogLevel:(int)theLevel {
    switch (theLevel) {
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
    }
    return @"none";
}

- (id)init {
    if (self = [super init]) {
        logFileManager = [[HSLogFileManager alloc] init];
        
        fileLogger = [[DDFileLogger alloc] initWithLogFileManager:logFileManager];
        fileLogger.rollingFrequency = 0; // Do not roll based on time.
        fileLogger.maximumFileSize = 100000000; // 100MB
        fileLogger.logFileManager.maximumNumberOfLogFiles = 10;
        [DDLog addLogger:fileLogger];
        
#ifdef DEBUG
        [DDLog addLogger:[DDTTYLogger sharedInstance]];
#endif
        
        ddLogLevel = DDLogLevelInfo;
        NSDictionary *bundleInfoDict = [[NSBundle mainBundle] infoDictionary];
        if ([bundleInfoDict objectForKey:@"CFBundleName"] != nil) {
            HSLogInfo(@"%@ version %@ started from %@", [bundleInfoDict objectForKey:@"CFBundleName"], [bundleInfoDict objectForKey:@"CFBundleVersion"], [[NSBundle mainBundle] bundlePath]);
        } else {
            NSString *exe = [[NSProcessInfo processInfo] arguments][0];
            HSLogInfo(@"%@ started from %@", exe, [[NSBundle mainBundle] bundlePath]);
        }
        HSLogInfo(@"OS X version: %@", [System productVersion:NULL]);
    }
    return self;
}
- (NSString *)errorDomain {
    return @"HSLogErrorDomain";
}

- (void)setHSLogLevel:(int)theLevel {
    if (theLevel != [self hsLogLevel]) {
        NSString *logLevelDescription = [NSString stringWithFormat:@"%d", theLevel];
        switch (theLevel) {
            case HSLOG_LEVEL_NONE:
                ddLogLevel = DDLogLevelOff;
                logLevelDescription = @"None";
                break;
            case HSLOG_LEVEL_ERROR:
                ddLogLevel = DDLogLevelError;
                logLevelDescription = @"Error";
                break;
            case HSLOG_LEVEL_WARN:
                ddLogLevel = DDLogLevelWarning;
                logLevelDescription = @"Warn";
                break;
            case HSLOG_LEVEL_INFO:
                ddLogLevel = DDLogLevelInfo;
                logLevelDescription = @"Info";
                break;
            case HSLOG_LEVEL_DETAIL:
                ddLogLevel = DDLogLevelDebug;
                logLevelDescription = @"Detail";
                break;
            case HSLOG_LEVEL_DEBUG:
                ddLogLevel = DDLogLevelVerbose;
                logLevelDescription = @"Debug";
                break;
            default:
                ddLogLevel = DDLogLevelOff;
        }
        [DDLog log:NO level:DDLogLevelAll flag:DDLogFlagInfo context:0 file:__FILE__ function:__PRETTY_FUNCTION__ line:__LINE__ tag:nil format:@"log level: %@", logLevelDescription];
    }
}
- (int)hsLogLevel {
    switch (ddLogLevel) {
        case DDLogLevelError:
            return HSLOG_LEVEL_ERROR;
        case DDLogLevelWarning:
            return HSLOG_LEVEL_WARN;
        case DDLogLevelInfo:
            return HSLOG_LEVEL_INFO;
        case DDLogLevelDebug:
            return HSLOG_LEVEL_DETAIL;
        case DDLogLevelVerbose:
            return HSLOG_LEVEL_DEBUG;
        default:
            return HSLOG_LEVEL_NONE;
    }
    return HSLOG_LEVEL_NONE;
}

@end
