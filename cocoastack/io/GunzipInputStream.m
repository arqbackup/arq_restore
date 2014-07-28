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



#import "GunzipInputStream.h"
#import "InputStreams.h"



#define MY_BUF_SIZE (4096)


@implementation GunzipInputStream
+ (NSString *)errorDomain {
    return @"GunzipInputStreamErrorDomain";
}
- (id)initWithUnderlyingStream:(id <InputStream>)theUnderlyingStream {
    if (self = [super init]) {
        underlyingStream = [theUnderlyingStream retain];
        stream.avail_in = 0;
        stream.avail_out = 0;
        stream.total_out = 0;
        stream.zalloc = Z_NULL;
        stream.zfree = Z_NULL;
        stream.opaque = Z_NULL;
        flush = Z_NO_FLUSH;
        inBuf = (unsigned char *)malloc(MY_BUF_SIZE);
    }
    return self;
}
- (void)dealloc {
    if (initialized) {
        inflateEnd(&stream);
    }
    [underlyingStream release];
    free(inBuf);
    [super dealloc];
}

#pragma mark InputStream
- (NSInteger)read:(unsigned char *)theBuf bufferLength:(NSUInteger)theBufferLength error:(NSError **)error {
    NSInteger recvd = 0;
    while (!eof && recvd == 0) {
        BOOL wasInitialized = initialized;
        if (!initialized) {
            int ret = inflateInit2(&stream, 15+32);
            if (ret != Z_OK) {
                SETNSERROR([GunzipInputStream errorDomain], ret, @"inflateInit error %d", ret);
                return -1;
            }
            initialized = YES;
        }
        if (!wasInitialized || stream.avail_out > 0) {
            // There weren't inflated bytes remaining last time, so read in some more before trying to inflate some more.
            stream.next_in = inBuf; // zlib changes next_in pointer so we have to reset it every time.
            stream.avail_in = (unsigned int)[underlyingStream read:stream.next_in bufferLength:MY_BUF_SIZE error:error];
            if (stream.avail_in <= 0) {
                return stream.avail_in;
            }
        }

        stream.next_out = theBuf;
        stream.avail_out = (unsigned int)theBufferLength;
        int ret = inflate(&stream, flush);
        switch (ret) {
            case Z_NEED_DICT:
            case Z_DATA_ERROR:
            case Z_MEM_ERROR:
                SETNSERROR([GunzipInputStream errorDomain], ret, @"inflate error %d", ret);
                return -1;
            case Z_STREAM_END:
                eof = YES;
        }
        recvd = theBufferLength - stream.avail_out;
    }
    return recvd;
}
- (NSData *)slurp:(NSError **)error {
    return [InputStreams slurp:self error:error];
}


#pragma mark NSObject 
- (NSString *)description {
    return [NSString stringWithFormat:@"<GunzipInputStream %@>", underlyingStream];
}
@end
