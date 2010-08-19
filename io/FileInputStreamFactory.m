/*
 Copyright (c) 2009-2010, Stefan Reitshamer http://www.haystacksoftware.com
 
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
#import "FileInputStreamFactory.h"
#import "FileInputStream.h"
#import "SetNSError.h"

@implementation FileInputStreamFactory
- (id)initWithPath:(NSString *)thePath offset:(unsigned long long)theOffset length:(unsigned long long)theLength {
    if (self = [super init]) {
        path = [thePath copy];
        offset = theOffset;
        length = theLength;
    }
    return self;
}
- (id)initWithPath:(NSString *)thePath error:(NSError **)error {
    struct stat st;
    if (lstat([thePath fileSystemRepresentation], &st) == -1) {
        SETNSERROR(@"UnixErrorDomain", errno, @"lstat(%@): %s", path, strerror(errno));
        return nil;
    }
    return [self initWithPath:thePath offset:0 length:(unsigned long long)st.st_size];
}
- (void)dealloc {
    [path release];
    [super dealloc];
}
- (id <InputStream>) newInputStream {
    return [[FileInputStream alloc] initWithPath:path offset:offset length:length];
}

#pragma mark NSObject
- (NSString *)description {
    return [NSString stringWithFormat:@"<FileISF: %@,length=%qu>", path, length];
}
@end
