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

#import "Computer.h"
#include <SystemConfiguration/SCDynamicStoreCopySpecific.h>


#define SERIAL_BUF_SIZE (1024)


static void get_serial_number(char *buf, int bufSize) {
    io_registry_entry_t ioRegistryRoot = IORegistryEntryFromPath(kIOMasterPortDefault, "IOService:/");
    CFStringRef uuidCf = (CFStringRef) IORegistryEntryCreateCFProperty(ioRegistryRoot, CFSTR(kIOPlatformSerialNumberKey), kCFAllocatorDefault, 0);
    IOObjectRelease(ioRegistryRoot);
    CFStringGetCString(uuidCf, buf, bufSize, kCFStringEncodingMacRoman);
    CFRelease(uuidCf);
}

@implementation Computer
+ (NSString *)name {
    NSString *theName = (NSString *)SCDynamicStoreCopyComputerName(NULL,NULL);
    if (theName == nil) {
        theName = [[NSString alloc] initWithString:@"unknown-computer-name"];
    }
    return [theName autorelease];
}
+ (NSString *)serialNumber {
    char buf[SERIAL_BUF_SIZE];
    get_serial_number(buf, SERIAL_BUF_SIZE);
    return [NSString stringWithUTF8String:buf];
}
+ (NSString *)machineType {
	OSErr err;
	char *machineName=NULL;    // This is really a Pascal-string with a length byte.
	err = Gestalt(gestaltUserVisibleMachineName, (SInt32*) &machineName); //gestaltUserVisibleMachineName = 'mnam'
	if (err != noErr) {
        return nil;
    }
    return [[[NSString alloc] initWithBytes:machineName+1 length:machineName[0] encoding:NSUTF8StringEncoding] autorelease];
}
@end
