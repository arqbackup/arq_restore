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



#include <pthread.h>
#import "CocoaLumberjack/CocoaLumberjack.h"
#import "CWLSynthesizeSingleton.h"
@class HSLogFileManager;


#define HSLOG_LEVEL_DEBUG (5)
#define HSLOG_LEVEL_DETAIL (4)
#define HSLOG_LEVEL_INFO (3)
#define HSLOG_LEVEL_WARN (2)
#define HSLOG_LEVEL_ERROR (1)
#define HSLOG_LEVEL_NONE (0)

#define HSLogDebug( s, ... ) DDLogVerbose(@"DEBUG [thread %x] %p %@:%d %@", pthread_mach_thread_np(pthread_self()), self, [@__FILE__ lastPathComponent], __LINE__, [NSString stringWithFormat:(s), ##__VA_ARGS__]);
#define HSLogDetail( s, ... ) DDLogDebug(@"DETAIL [thread %x] %@", pthread_mach_thread_np(pthread_self()), [NSString stringWithFormat:(s), ##__VA_ARGS__]);
#define HSLogInfo( s, ... ) DDLogInfo(@"INFO [thread %x] %@", pthread_mach_thread_np(pthread_self()), [NSString stringWithFormat:(s), ##__VA_ARGS__]);
#define HSLogWarn( s, ... ) DDLogWarn(@"WARN [thread %x] %@", pthread_mach_thread_np(pthread_self()), [NSString stringWithFormat:(s), ##__VA_ARGS__]);
#define HSLogError( s, ... ) DDLogError(@"ERROR [thread %x] %@", pthread_mach_thread_np(pthread_self()), [NSString stringWithFormat:(s), ##__VA_ARGS__]);


extern DDLogLevel ddLogLevel;

@interface HSLog : NSObject {
    HSLogFileManager *logFileManager;
    DDFileLogger *fileLogger;
}
CWL_DECLARE_SINGLETON_FOR_CLASS(HSLog)

+ (int)hsLogLevelForName:(NSString *)theName;
+ (NSString *)nameForHSLogLevel:(int)theLevel;
- (void)setHSLogLevel:(int)theLevel;
- (int)hsLogLevel;
@end
