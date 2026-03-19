// Software License Agreement (BSD License)
//
// Copyright (c) 2010-2015, Deusty, LLC
// All rights reserved.
//
// Redistribution and use of this software in source and binary forms,
// with or without modification, are permitted provided that the following conditions are met:
//
// * Redistributions of source code must retain the above copyright notice,
//   this list of conditions and the following disclaimer.
//
// * Neither the name of Deusty nor the names of its contributors may be used
//   to endorse or promote products derived from this software without specific
//   prior written permission of Deusty, LLC.

// DDASLLogger is a no-op stub. Apple System Log (asl) was deprecated in
// macOS 10.12 and removed from the SDK in macOS 10.15. This project uses
// DDFileLogger and DDTTYLogger instead; DDASLLogger is retained only for
// interface compatibility.

#import "DDASLLogger.h"

const char* const kDDASLKeyDDLog = "DDLog";
const char* const kDDASLDDLogValue = "1";

static DDASLLogger *sharedInstance;

@implementation DDASLLogger

+ (instancetype)sharedInstance {
    static dispatch_once_t DDASLLoggerOnceToken;
    dispatch_once(&DDASLLoggerOnceToken, ^{
        sharedInstance = [[[self class] alloc] init];
    });
    return sharedInstance;
}

- (void)logMessage:(DDLogMessage *)logMessage {
    // No-op: ASL is not available on modern macOS.
}

- (NSString *)loggerName {
    return @"cocoa.lumberjack.aslLogger";
}

@end
