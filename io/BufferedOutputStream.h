//
//  BufferedOutputStream.h
//  iPhotoSync
//
//  Created by Stefan Reitshamer on 8/25/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//


#import "OutputStream.h"

@interface BufferedOutputStream : NSObject <OutputStream> {
    id <OutputStream> os;
    unsigned char *buf;
    NSUInteger pos;
    NSUInteger buflen;
    uint64_t totalBytesWritten;
    BOOL errorOccurred;
}
+ (NSString *)errorDomain;
- (id)initWithMutableData:(NSMutableData *)theMutableData;
- (id)initWithFD:(int)theFD;
- (id)initWithPath:(NSString *)thePath append:(BOOL)isAppend;
- (id)initWithPath:(NSString *)thePath targetUID:(uid_t)theTargetUID targetGID:(gid_t)theTargetGID append:(BOOL)isAppend;
- (id)initWithUnderlyingOutputStream:(id <OutputStream>)theOS;
- (BOOL)setBufferSize:(NSUInteger)size error:(NSError **)error;
- (BOOL)writeFully:(const unsigned char *)buf length:(NSUInteger)len error:(NSError **)error;
- (BOOL)flush:(NSError **)error;
@end
