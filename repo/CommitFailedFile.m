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

#import "CommitFailedFile.h"
#import "StringIO.h"
#import "BufferedInputStream.h"

@implementation CommitFailedFile
- (id)initWithPath:(NSString *)thePath errorMessage:(NSString *)theErrorMessage {
    if (self = [super init]) {
        path = [thePath copy];
        errorMessage = [theErrorMessage copy];
    }
    return self;
}
- (id)initWithInputStream:(BufferedInputStream *)is error:(NSError **)error {
    if (self = [super init]) {
        if (![StringIO read:&path from:is error:error]
            || ![StringIO read:&errorMessage from:is error:error]) {
            [self release];
            return nil;
        }
        [path retain];
        [errorMessage retain];
    }
    return self;
}
- (void)dealloc {
    [path release];
    [errorMessage release];
    [super dealloc];
}
- (NSString *)path {
    return [[path retain] autorelease];
}
- (NSString *)errorMessage {
    return [[errorMessage retain] autorelease];
}
- (void)writeTo:(NSMutableData *)data {
    [StringIO write:path to:data];
    [StringIO write:errorMessage to:data];
}
- (BOOL)isEqualToCommitFailedFile:(CommitFailedFile *)cff {
    return [[cff path] isEqualToString:path] && [[cff errorMessage] isEqualToString:errorMessage];
}

#pragma mark NSObject
- (BOOL)isEqual:(id)other {
    if (other == self) {
        return YES;
    }
    if (other == nil || ![other isKindOfClass:[self class]]) {
        return NO;
    }
    return [self isEqualToCommitFailedFile:other];
}
@end
