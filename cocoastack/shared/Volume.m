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



#import "Volume.h"


@implementation Volume
+ (NSString *)errorDomain {
    return @"VolumeErrorDomain";
}

- (id)initWithURL:(NSURL *)theURL
       mountPoint:(NSString *)theMountPoint
       fileSystem:(NSString *)theFileSystem
       fsTypeName:(NSString *)theFSTypeName
           fsType:(uint32_t)theFSType
            owner:(uid_t)theOwner
             name:(NSString *)theName
         isRemote:(BOOL)theIsRemote {
    if (self = [super init]) {
        url = [theURL retain];
        mountPoint = [theMountPoint retain];
        fileSystem = [theFileSystem retain];
        fsTypeName = [theFSTypeName retain];
        fsType = theFSType;
        owner = theOwner;
        name = [theName retain];
        isRemote = theIsRemote;
    }
    return self;
}
- (void)dealloc {
    [url release];
    [mountPoint release];
    [fileSystem release];
    [fsTypeName release];
    [name release];
    [super dealloc];
}

- (NSURL *)url {
    return url;
}
- (NSString *)mountPoint {
    return mountPoint;
}
- (NSString *)name {
    return name;
}
- (BOOL)isRemote {
    return isRemote;
}


#pragma mark NSObject
- (NSString *)description {
    return [NSString stringWithFormat:@"<Volume:  url=%@,mountpoint=%@,filesystem=%@,fstypename=%@,fstype=%d,owner=%d,name=%@,remote=%@>", url, mountPoint, fileSystem, fsTypeName, fsType, owner, name, (isRemote ? @"YES" : @"NO")];
}
@end

@implementation Volume (internal)
@end
