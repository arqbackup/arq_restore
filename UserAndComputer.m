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

#import "UserAndComputer.h"
#import "Computer.h"
#import "DictNode.h"

@implementation UserAndComputer
- (id)init {
    if (self = [super init]) {
        userName = [NSUserName() copy];
        computerName = [[Computer name] copy];
    }
    return self;
}
- (id)initWithXMLData:(NSData *)theXMLData error:(NSError **)error {
    if (self = [super init]) {
        DictNode *plist = [DictNode dictNodeWithXMLData:theXMLData error:error];
        if (plist == nil) {
            [self release];
            return nil;
        }
        userName = [[[plist stringNodeForKey:@"userName"] stringValue] copy];
        computerName = [[[plist stringNodeForKey:@"computerName"] stringValue] copy];
    }
    return self;
}
- (id)initWithUserName:(NSString *)theUserName computerName:(NSString *)theComputerName {
    if (self = [super init]) {
        userName = [theUserName retain];
        computerName = [theComputerName retain];
    }
    return self;
}
- (void)dealloc {
    [userName release];
    [computerName release];
    [super dealloc];
}
- (NSString *)userName {
    return userName;
}
- (NSString *)computerName {
    return computerName;
}
- (NSData *)toXMLData {
    DictNode *plist = [[[DictNode alloc] init] autorelease];
    [plist putString:userName forKey:@"userName"];
    [plist putString:computerName forKey:@"computerName"];
    return [plist XMLData];
}

#pragma mark NSObject
- (NSString *)description {
    return [NSString stringWithFormat:@"<UserAndComputer: userName=%@ computerName=%@>", userName, computerName];
}
@end
