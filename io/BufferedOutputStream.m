//
//  BufferedOutputStream.m
//  iPhotoSync
//
//  Created by Stefan Reitshamer on 8/25/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "BufferedOutputStream.h"
#import "NSErrorCodes.h"
#import "SetNSError.h"
#import "DataOutputStream.h"
#import "FDOutputStream.h"
#import "FileOutputStream.h"

#define MY_BUF_SIZE (4096)

@implementation BufferedOutputStream
+ (NSString *)errorDomain {
    return @"BufferedOutputStreamErrorDomain";
}
- (id)initWithMutableData:(NSMutableData *)theMutableData {
    DataOutputStream *dos = [[DataOutputStream alloc] initWithMutableData:theMutableData];
    id ret = [self initWithUnderlyingOutputStream:dos];
    [dos release];
    return ret;
}
- (id)initWithFD:(int)theFD {
    FDOutputStream *fdos = [[FDOutputStream alloc] initWithFD:theFD];
    id ret = [self initWithUnderlyingOutputStream:fdos];
    [fdos release];
    return ret;
}
- (id)initWithPath:(NSString *)thePath append:(BOOL)isAppend {
    FileOutputStream *fos = [[FileOutputStream alloc] initWithPath:thePath append:isAppend];
    id ret = [self initWithUnderlyingOutputStream:fos];
    [fos release];
    return ret;
}
- (id)initWithPath:(NSString *)thePath targetUID:(uid_t)theTargetUID targetGID:(gid_t)theTargetGID append:(BOOL)isAppend {
    FileOutputStream *fos = [[FileOutputStream alloc] initWithPath:thePath targetUID:theTargetUID targetGID:theTargetGID append:isAppend];
    id ret = [self initWithUnderlyingOutputStream:fos];
    [fos release];
    return ret;
}
- (id)initWithUnderlyingOutputStream:(id <OutputStream>)theOS {
    if (self = [super init]) {
        os = [theOS retain];
        buflen = MY_BUF_SIZE;
        buf = (unsigned char *)malloc(buflen);
    }
    return self;
}
- (void)dealloc {
    if (pos > 0 && !errorOccurred) {
        HSLogWarn(@"BufferedOutputStream pos > 0 -- flush wasn't called?!");
    }
    [os release];
    free(buf);
    [super dealloc];
}
- (BOOL)setBufferSize:(NSUInteger)size error:(NSError **)error {
    if (![self flush:error]) {
        return NO;
    }
    buf = realloc(buf, size);
    buflen = size;
    return YES;
}
- (BOOL)flush:(NSError **)error {
    NSAssert(os != nil, @"write: os can't be nil");
    NSUInteger index = 0;
    while (index < pos) {
        NSInteger written = [os write:&buf[index] length:(pos - index) error:error];
        if (written < 0) {
            errorOccurred = YES;
            return NO;
        }
        if (written == 0) {
            SETNSERROR([BufferedOutputStream errorDomain], ERROR_EOF, @"0 bytes written to underlying stream %@", [os description]);
            errorOccurred = YES;
            return NO;
        }
        index += written;
    }
    pos = 0;
    return YES;
}
- (BOOL)writeFully:(const unsigned char *)theBuf length:(NSUInteger)len error:(NSError **)error {
    NSUInteger totalWritten = 0;
    while (totalWritten < len) {
        NSInteger writtenThisTime = [self write:&theBuf[totalWritten] length:(len - totalWritten) error:error];
        if (writtenThisTime < 0) {
            return NO;
        }
        totalWritten += (NSUInteger)writtenThisTime;
    }
    NSAssert(totalWritten == len, @"writeFully must return as all bytes written");
    return YES;
}

#pragma mark OutputStream
- (NSInteger)write:(const unsigned char *)theBuf length:(NSUInteger)theLen error:(NSError **)error {
    NSAssert(os != nil, @"write: os can't be nil");
    if ((pos + theLen) > buflen) {
        if (![self flush:error]) {
            errorOccurred = YES;
            return -1;
        }
    }
    if (theLen > buflen) {
        NSUInteger written = 0;
        // Loop to write theBuf directly to the underlying stream, since it won't fit in our buffer.
        while (written < theLen) {
            NSInteger writtenThisTime = [os write:&theBuf[written] length:(theLen - written) error:error];
            if (writtenThisTime < 0) {
                errorOccurred = YES;
                return -1;
            }
            if (writtenThisTime == 0) {
                SETNSERROR([BufferedOutputStream errorDomain], ERROR_EOF, @"0 bytes written to underlying stream");
                errorOccurred = YES;
                return -1;
            }
            written += writtenThisTime;
        }
    } else {
        memcpy(buf + pos, theBuf, theLen);
        pos += theLen;
    }
    totalBytesWritten += theLen;
    return theLen;
}
- (unsigned long long)bytesWritten {
    return totalBytesWritten;
}

#pragma mark NSObject
- (NSString *)description {
    return [NSString stringWithFormat:@"<BufferedOutputStream underlying=%@>", os];
}
@end
