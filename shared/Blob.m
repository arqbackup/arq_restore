/*
 Copyright (c) 2009, Stefan Reitshamer http://www.haystacksoftware.com
 
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

#import "Blob.h"
#import "DataInputStreamFactory.h"

@implementation Blob
- (id)initWithInputStreamFactory:(id <InputStreamFactory>)theFactory mimeType:(NSString *)theMimeType downloadName:(NSString *)theDownloadName {
    if (self = [super init]) {
        mimeType = [theMimeType copy];
        downloadName = [theDownloadName copy];
        gzipped = NO;
        inputStreamFactory = [theFactory retain];
        entireSource = YES;
    }
    return self;
}
- (id)initWithInputStreamFactory:(id <InputStreamFactory>)theFactory sourceOffset:(unsigned long long)theOffset sourceLength:(unsigned long long)theLength mimeType:(NSString *)theMimeType downloadName:(NSString *)theDownloadName {
    if (self = [super init]) {
        mimeType = [theMimeType copy];
        downloadName = [theDownloadName copy];
        gzipped = NO;
        inputStreamFactory = [theFactory retain];
        entireSource = NO;
        sourceOffset = theOffset;
        sourceLength = theLength;
    }
    return self;
}
- (id)initWithData:(NSData *)theData mimeType:(NSString *)theMimeType downloadName:(NSString *)theDownloadName {
    if (self = [super init]) {
        mimeType = [theMimeType copy];
        downloadName = [theDownloadName copy];
        gzipped = NO;
        inputStreamFactory = [[DataInputStreamFactory alloc] initWithData:theData];
        entireSource = YES;
    }
    return self;
}
- (id)initWithGzippedData:(NSData *)theData mimeType:(NSString *)theMimeType downloadName:(NSString *)theDownloadName {
    if (self = [super init]) {
        mimeType = [theMimeType copy];
        downloadName = [theDownloadName copy];
        gzipped = YES;
        inputStreamFactory = [[DataInputStreamFactory alloc] initWithData:theData];
        entireSource = YES;
    }
    return self;
}
- (void)dealloc {
    [mimeType release];
    [downloadName release];
    [inputStreamFactory release];
	[super dealloc];
}
- (NSString *)mimeType {
    return mimeType;
}
- (NSString *)downloadName {
    return downloadName;
}
- (BOOL)gzipped {
    return gzipped;
}
- (id <InputStream>)newInputStream:(id)sender {
    id <InputStream> is = nil;
    if (entireSource) {
        is = [inputStreamFactory newInputStream:sender];
    } else {
        is = [inputStreamFactory newInputStream:sender sourceOffset:sourceOffset sourceLength:sourceLength];
    }
    return is;
}
- (NSData *)slurp:(NSError **)error {
    return [self slurp:self error:error];
}
- (NSData *)slurp:(id)sender error:(NSError **)error {
    id <InputStream> is = [self newInputStream:sender];
    NSData *data = [is slurp:error];
    [is release];
    return data;
}
@end
