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



#import "StandardRestorerDelegateMux.h"

@implementation StandardRestorerDelegateMux
- (id)initWithStandardRestorerDelegate:(id <StandardRestorerDelegate>)theSRD {
    if (self = [super init]) {
        srd = theSRD;
        lock = [[NSLock alloc] init];
        [lock setName:@"StandardRestorerDelegateMux lock"];
    }
    return self;
}
- (void)dealloc {
    [lock release];
    [super dealloc];
}


#pragma mark StandardRestorerDelegate
- (BOOL)standardRestorerMessageDidChange:(NSString *)message {
    [lock lock];
    BOOL ret = [srd standardRestorerMessageDidChange:message];
    [lock unlock];
    return ret;
}
- (BOOL)standardRestorerFileBytesRestoredDidChange:(NSNumber *)theTransferred {
    [lock lock];
    BOOL ret = [srd standardRestorerFileBytesRestoredDidChange:theTransferred];
    [lock unlock];
    return ret;
}
- (BOOL)standardRestorerTotalFileBytesToRestoreDidChange:(NSNumber *)theTotal {
    [lock lock];
    BOOL ret = [srd standardRestorerTotalFileBytesToRestoreDidChange:theTotal];
    [lock unlock];
    return ret;
}
- (BOOL)standardRestorerErrorMessage:(NSString *)theErrorMessage didOccurForPath:(NSString *)thePath {
    [lock lock];
    BOOL ret = [srd standardRestorerErrorMessage:theErrorMessage didOccurForPath:thePath];
    [lock unlock];
    return ret;
}
- (BOOL)standardRestorerDidSucceed {
    [lock lock];
    BOOL ret = [srd standardRestorerDidSucceed];
    [lock unlock];
    return ret;
}
- (BOOL)standardRestorerDidFail:(NSError *)error {
    [lock lock];
    BOOL ret = [srd standardRestorerDidFail:error];
    [lock unlock];
    return ret;
}
@end
