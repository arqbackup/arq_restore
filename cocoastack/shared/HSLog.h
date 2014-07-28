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


#include <pthread.h>

extern unsigned int global_hslog_level;

extern void setHSLogLevel(int level);
extern int hsLogLevelForName(NSString *levelName);
extern NSString *nameForHSLogLevel(int level);
#define HSLOG_LEVEL_TRACE (6)
#define HSLOG_LEVEL_DEBUG (5)
#define HSLOG_LEVEL_DETAIL (4)
#define HSLOG_LEVEL_INFO (3)
#define HSLOG_LEVEL_WARN (2)
#define HSLOG_LEVEL_ERROR (1)
#define HSLOG_LEVEL_NONE (0)

#define HSLogTrace( s, ... ) { if (global_hslog_level >= HSLOG_LEVEL_TRACE) { NSLog(@"TRACE [thread %x] %p %@:%d %@", pthread_mach_thread_np(pthread_self()), self, [@__FILE__ lastPathComponent], __LINE__, [NSString stringWithFormat:(s), ##__VA_ARGS__]); } }
#define HSLogDebug( s, ... ) { if (global_hslog_level >= HSLOG_LEVEL_DEBUG) { NSLog(@"DEBUG [thread %x] %p %@:%d %@", pthread_mach_thread_np(pthread_self()), self, [@__FILE__ lastPathComponent], __LINE__, [NSString stringWithFormat:(s), ##__VA_ARGS__]); } }
#define HSLogDebugStatic( s, ... ) { if (global_hslog_level >= HSLOG_LEVEL_DEBUG) { NSLog(@"DEBUG [thread %x] %@:%d %@", pthread_mach_thread_np(pthread_self()), [@__FILE__ lastPathComponent], __LINE__, [NSString stringWithFormat:(s), ##__VA_ARGS__]); } }
#define HSLogDetail( s, ... ) { if (global_hslog_level >= HSLOG_LEVEL_DETAIL) { NSLog(@"DETAIL [thread %x]  %@", pthread_mach_thread_np(pthread_self()), [NSString stringWithFormat:(s), ##__VA_ARGS__]); } }
#define HSLogInfo( s, ... ) { if (global_hslog_level >= HSLOG_LEVEL_INFO) { NSLog(@"INFO [thread %x]  %@", pthread_mach_thread_np(pthread_self()), [NSString stringWithFormat:(s), ##__VA_ARGS__]); } }
#define HSLogWarn( s, ... ) { if (global_hslog_level >= HSLOG_LEVEL_WARN) { NSLog(@"WARN [thread %x]  %@", pthread_mach_thread_np(pthread_self()), [NSString stringWithFormat:(s), ##__VA_ARGS__]); } }
#define HSLogError( s, ... ) { if (global_hslog_level >= HSLOG_LEVEL_ERROR) { NSLog(@"ERROR [thread %x] %@", pthread_mach_thread_np(pthread_self()), [NSString stringWithFormat:(s), ##__VA_ARGS__]); } }
#define HSLog( s, ... )  NSLog(@"%@", [NSString stringWithFormat:(s), ##__VA_ARGS__])
