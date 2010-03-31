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

#import "StringIO.h"
#import "IntegerIO.h"
#import "BooleanIO.h"
#import "Node.h"
#import "Tree.h"
#import "Blob.h"
#import "DataInputStream.h"
#import "SetNSError.h"
#import "RegexKitLite.h"
#import "NSErrorCodes.h"
#import "Streams.h"

#define HEADER_LENGTH (8)

@interface Tree (internal)
- (BOOL)readHeader:(id <BufferedInputStream>)is error:(NSError **)error;
@end

@implementation Tree
@synthesize xattrsSHA1, xattrsSize, aclSHA1, uid, gid, mode, mtime_sec, mtime_nsec, flags, finderFlags, extendedFinderFlags, treeVersion, st_rdev;
@synthesize ctime_sec, ctime_nsec, createTime_sec, createTime_nsec, st_nlink, st_ino;

- (id)init {
    if (self = [super init]) {
        nodes = [[NSMutableDictionary alloc] init];
    }
    return self;
}
- (id)initWithBufferedInputStream:(id <BufferedInputStream>)is error:(NSError **)error {
	if (self = [super init]) {
        if (![self readHeader:is error:error]) {
            [self release];
            return nil;
        }
        BOOL ret = [StringIO read:&xattrsSHA1 from:is error:error]
        && [IntegerIO readUInt64:&xattrsSize from:is error:error]
        &&[StringIO read:&aclSHA1 from:is error:error]
        && [IntegerIO readInt32:&uid from:is error:error]
        && [IntegerIO readInt32:&gid from:is error:error]
        && [IntegerIO readInt32:&mode from:is error:error]
        && [IntegerIO readInt64:&mtime_sec from:is error:error]
        && [IntegerIO readInt64:&mtime_nsec from:is error:error]
        && [IntegerIO readInt64:&flags from:is error:error]
        && [IntegerIO readInt32:&finderFlags from:is error:error]
        && [IntegerIO readInt32:&extendedFinderFlags from:is error:error]
        && [IntegerIO readInt32:&st_dev from:is error:error]
        && [IntegerIO readInt32:&st_ino from:is error:error]
        && [IntegerIO readUInt32:&st_nlink from:is error:error]
        && [IntegerIO readInt32:&st_rdev from:is error:error]
        && [IntegerIO readInt64:&ctime_sec from:is error:error]
        && [IntegerIO readInt64:&ctime_nsec from:is error:error]
        && [IntegerIO readInt64:&st_blocks from:is error:error]
        && [IntegerIO readUInt32:&st_blksize from:is error:error];
        [xattrsSHA1 retain];
        [aclSHA1 retain];
        
        if (!ret) {
            goto initError;
        }
        
        unsigned int nodeCount;
        if (![IntegerIO readUInt32:&nodeCount from:is error:error]) {
            goto initError;
        }
        nodes = [[NSMutableDictionary alloc] init];
        for (unsigned int i = 0; i < nodeCount; i++) {
            NSString *nodeName;
            if (![StringIO read:&nodeName from:is error:error]) {
                goto initError;
            }
            Node *node = [[Node alloc] initWithInputStream:is treeVersion:treeVersion error:error];
            if (!node) {
                goto initError;
            }
            [nodes setObject:node forKey:nodeName];
            [node release];
        }
        goto initDone;
    initError:
        [self release];
        self = nil;
	}
initDone:
	return self;
}
- (void)dealloc {
    [xattrsSHA1 release];
    [aclSHA1 release];
	[nodes release];
	[super dealloc];
}
- (NSArray *)childNodeNames {
	return [nodes allKeys];
}
- (Node *)childNodeWithName:(NSString *)name {
	return [nodes objectForKey:name];
}
- (BOOL)containsNodeNamed:(NSString *)name {
	return [nodes objectForKey:name] != nil;
}
@end

@implementation Tree (internal)
- (BOOL)readHeader:(id <BufferedInputStream>)is error:(NSError **)error {
    unsigned char *headerBytes = [is readExactly:HEADER_LENGTH error:error];
    if (headerBytes == NULL) {
        return NO;
    }
    NSString *header = [[[NSString alloc] initWithBytes:headerBytes length:HEADER_LENGTH encoding:NSASCIIStringEncoding] autorelease];
    NSRange versionRange = [header rangeOfRegex:@"^TreeV(\\d{3})$" capture:1];
    treeVersion = 0;
    if (versionRange.location != NSNotFound) {
        NSNumberFormatter *nf = [[NSNumberFormatter alloc] init];
        NSNumber *number = [nf numberFromString:[header substringWithRange:versionRange]];
        treeVersion = [number intValue];
        [nf release];
    }
    if (treeVersion != CURRENT_TREE_VERSION) {
        SETNSERROR(@"TreeErrorDomain", ERROR_INVALID_OBJECT_VERSION, @"invalid Tree header: %@", header);
        return NO;
    }
    return YES;
}
@end
