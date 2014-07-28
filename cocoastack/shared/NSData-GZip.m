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

#import "NSData-GZip.h"
#include <zlib.h>

@implementation NSData (GZip)
- (NSData *)gzipInflate:(NSError **)error {
    if ([self length] == 0) {
        return self;
    }
    
    unsigned full_length = (unsigned)[self length];
    unsigned half_length = (unsigned)[self length] / 2;
    
    NSMutableData *decompressed = [NSMutableData dataWithLength: full_length + half_length];
    BOOL done = NO;
    int status;
    
    z_stream stream;
    stream.next_in = (Bytef *)[self bytes];
    stream.avail_in = (unsigned)[self length];
    stream.total_out = 0;
    stream.zalloc = Z_NULL;
    stream.zfree = Z_NULL;
    
    if (inflateInit2(&stream, (15+32)) != Z_OK) {
        SETNSERROR(@"GunzipErrorDomain", -1, @"inflateinit2 failed");
        return nil;
    }
    while (!done) {
        // Make sure we have enough room and reset the lengths.
        if (stream.total_out >= [decompressed length]) {
            [decompressed increaseLengthBy: half_length];
		}
        stream.next_out = [decompressed mutableBytes] + stream.total_out;
        stream.avail_out = (unsigned int)([decompressed length] - stream.total_out);
        
        // Inflate another chunk.
        status = inflate (&stream, Z_SYNC_FLUSH);
        if (status == Z_STREAM_END) {
			done = YES;
		} else if (status != Z_OK) {
            switch (status) {
                case Z_NEED_DICT:
                    HSLogError(@"Z_NEED_DICT");
                    break;
                case Z_STREAM_ERROR:
                    HSLogError(@"Z_STREAM_ERROR");
                    break;
                case Z_DATA_ERROR:
                    HSLogError(@"Z_DATA_ERROR");
                    break;
                case Z_MEM_ERROR:
                    HSLogError(@"Z_MEM_ERROR");
                    break;
                case Z_BUF_ERROR:
                    HSLogError(@"Z_BUF_ERROR");
                    break;
                default:
                    HSLogError(@"inflate error");
                    break;
            }
			break;
		}
    }
    if (inflateEnd (&stream) != Z_OK) {
        SETNSERROR(@"GunzipErrorDomain", -1, @"inflateEnd failed");
        return nil;
    }
    
    // Set real length.
    if (done) {
        [decompressed setLength: stream.total_out];
        return [NSData dataWithData: decompressed];
    } else {
        SETNSERROR(@"GunzipErrorDomain", -1, @"inflate failed");
        return nil;
    }
}
- (NSData *)gzipDeflate {
    if ([self length] == 0) {
        return self;
    }
    
    z_stream strm;
    
    strm.zalloc = Z_NULL;
    strm.zfree = Z_NULL;
    strm.opaque = Z_NULL;
    strm.total_out = 0;
    strm.next_in=(Bytef *)[self bytes];
    strm.avail_in = (unsigned int)[self length];
    
    // Compresssion Levels:
    //   Z_NO_COMPRESSION
    //   Z_BEST_SPEED
    //   Z_BEST_COMPRESSION
    //   Z_DEFAULT_COMPRESSION
    
    if (deflateInit2(&strm, Z_DEFAULT_COMPRESSION, Z_DEFLATED, (15+16), 8, Z_DEFAULT_STRATEGY) != Z_OK) {
        return nil;
    }
    
    NSMutableData *compressed = [NSMutableData dataWithLength:16384];  // 16K chunks for expansion
    
    do {
        if (strm.total_out >= [compressed length]) {
            [compressed increaseLengthBy: 16384];
		}
        
        strm.next_out = [compressed mutableBytes] + strm.total_out;
        strm.avail_out = (unsigned int)([compressed length] - strm.total_out);
        
        deflate(&strm, Z_FINISH);  
        
    } while (strm.avail_out == 0);
    
    deflateEnd(&strm);
    
    [compressed setLength: strm.total_out];
    return compressed;
}

@end
