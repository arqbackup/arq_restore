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

// DDASLLogCapture is a no-op stub. Apple System Log (asl) was deprecated in
// macOS 10.12 and removed from the SDK in macOS 10.15.

#import "DDASLLogCapture.h"

static DDLogLevel _captureLevel = DDLogLevelVerbose;

@implementation DDASLLogCapture

+ (void)start {
    // No-op: ASL is not available on modern macOS.
}

+ (void)stop {
    // No-op.
}

+ (DDLogLevel)captureLevel {
    return _captureLevel;
}

+ (void)setCaptureLevel:(DDLogLevel)level {
    _captureLevel = level;
}

@end
