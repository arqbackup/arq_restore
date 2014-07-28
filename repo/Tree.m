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


#include <sys/stat.h>
#import "StringIO.h"
#import "IntegerIO.h"
#import "BooleanIO.h"
#import "Node.h"
#import "Tree.h"
#import "DataInputStream.h"
#import "RegexKitLite.h"
#import "BufferedInputStream.h"
#import "NSData-Gzip.h"
#import "GunzipInputStream.h"
#import "BlobKey.h"
#import "NSObject_extra.h"
#import "BlobKeyIO.h"


@interface Tree (internal)
- (BOOL)readHeader:(BufferedInputStream *)is error:(NSError **)error;
@end

@implementation Tree
@synthesize xattrsAreCompressed, xattrsBlobKey, xattrsSize, aclIsCompressed, aclBlobKey, uid, gid, mode, mtime_sec, mtime_nsec, flags, finderFlags, extendedFinderFlags, st_dev, treeVersion, st_rdev;
@synthesize ctime_sec, ctime_nsec, createTime_sec, createTime_nsec, st_nlink, st_ino, st_blocks, st_blksize;
@dynamic aggregateUncompressedDataSize;


+ (NSString *)errorDomain {
    return @"TreeErrorDomain";
}
- (id)init {
    if (self = [super init]) {
        nodes = [[NSMutableDictionary alloc] init];
        missingNodes = [[NSMutableDictionary alloc] init];
    }
    return self;
}
- (id)initWithBufferedInputStream:(BufferedInputStream *)is error:(NSError **)error {
	if (self = [super init]) {
        nodes = [[NSMutableDictionary alloc] init];
        missingNodes = [[NSMutableDictionary alloc] init];

        if (![self readHeader:is error:error]) {
            [self release];
            return nil;
        }
        if (treeVersion >= 12) {
            if (![BooleanIO read:&xattrsAreCompressed from:is error:error]
                || ![BooleanIO read:&aclIsCompressed from:is error:error]) {
                [self release];
                return nil;
            }
        }
        
        BOOL ret = [BlobKeyIO read:&xattrsBlobKey from:is treeVersion:treeVersion compressed:xattrsAreCompressed error:error]
        && [IntegerIO readUInt64:&xattrsSize from:is error:error]
        && [BlobKeyIO read:&aclBlobKey from:is treeVersion:treeVersion compressed:aclIsCompressed error:error]
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
        [xattrsBlobKey retain];
        [aclBlobKey retain];
        if (!ret) {
            goto initError;
        }
        if ([xattrsBlobKey sha1] == nil) {
            [xattrsBlobKey release];
            xattrsBlobKey = nil;
        }
        if ([aclBlobKey sha1] == nil) {
            [aclBlobKey release];
            aclBlobKey = nil;
        }
        
        if (treeVersion >= 11 && treeVersion <= 16) {
            uint64_t unusedAggregateSizeOnDisk;
            if (![IntegerIO readUInt64:&unusedAggregateSizeOnDisk from:is error:error]) {
                goto initError;
            }
        }
        if (treeVersion >= 15) {
            if (![IntegerIO readInt64:&createTime_sec from:is error:error]
                || ![IntegerIO readInt64:&createTime_nsec from:is error:error]) {
                goto initError;
            }
        }
        
        if (treeVersion >= 18) {
            uint32_t missingNodeCount;
            if (![IntegerIO readUInt32:&missingNodeCount from:is error:error]) {
                goto initError;
            }
            for (uint32_t i = 0; i < missingNodeCount; i++) {
                NSString *missingNodeName = nil;
                if (![StringIO read:&missingNodeName from:is error:error]) {
                    goto initError;
                }
                Node *node = [[[Node alloc] initWithInputStream:is treeVersion:treeVersion error:error] autorelease];
                if (node == nil) {
                    goto initError;
                }
                [missingNodes setObject:node forKey:missingNodeName];
            }
        }
        
        uint32_t nodeCount;
        if (![IntegerIO readUInt32:&nodeCount from:is error:error]) {
            goto initError;
        }
        for (uint32_t i = 0; i < nodeCount; i++) {
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
    [xattrsBlobKey release];
    [aclBlobKey release];
	[nodes release];
    [missingNodes release];
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
- (BOOL)containsMissingItems {
    if ([missingNodes count] > 0) {
        return YES;
    }
    for (Node *node in [nodes allValues]) {
        if ([node isTree] && [node treeContainsMissingItems]) {
            return YES;
        }
    }
    return NO;
}
- (NSArray *)missingChildNodeNames {
    return [missingNodes allKeys];
}
- (Node *)missingChildNodeWithName:(NSString *)name {
    return [missingNodes objectForKey:name];
}
- (void)removeMissingChildNodeWithName:(NSString *)name {
    [missingNodes removeObjectForKey:name];
}
- (NSDictionary *)nodes {
    return nodes;
}
- (NSDictionary *)missingNodes {
    return missingNodes;
}
- (NSData *)toData {
    NSMutableData *data = [[[NSMutableData alloc] init] autorelease];
    [BooleanIO write:xattrsAreCompressed to:data];
    [BooleanIO write:aclIsCompressed to:data];
    [BlobKeyIO write:xattrsBlobKey to:data];
    [IntegerIO writeUInt64:xattrsSize to:data];
    [BlobKeyIO write:aclBlobKey to:data];
    [IntegerIO writeInt32:uid to:data];
    [IntegerIO writeInt32:gid to:data];
    [IntegerIO writeInt32:mode to:data];
    [IntegerIO writeInt64:mtime_sec to:data];
    [IntegerIO writeInt64:mtime_nsec to:data];
    [IntegerIO writeInt64:flags to:data];
    [IntegerIO writeInt32:finderFlags to:data];
    [IntegerIO writeInt32:extendedFinderFlags to:data];
    [IntegerIO writeInt32:st_dev to:data];
    [IntegerIO writeInt32:st_ino to:data];
    [IntegerIO writeUInt32:st_nlink to:data];
    [IntegerIO writeInt32:st_rdev to:data];
    [IntegerIO writeInt64:ctime_sec to:data];
    [IntegerIO writeInt64:ctime_nsec to:data];
    [IntegerIO writeInt64:st_blocks to:data];
    [IntegerIO writeUInt32:st_blksize to:data];
    [IntegerIO writeInt64:createTime_sec to:data];
    [IntegerIO writeInt64:createTime_nsec to:data];
    
    [IntegerIO writeUInt32:(uint32_t)[missingNodes count] to:data];
    for (NSString *missingNodeName in [missingNodes allKeys]) {
        [StringIO write:missingNodeName to:data];
        [[missingNodes objectForKey:missingNodeName] writeToData:data];
    }
    
    [IntegerIO writeUInt32:(uint32_t)[nodes count] to:data];
    NSMutableArray *nodeNames = [NSMutableArray arrayWithArray:[nodes allKeys]];
    [nodeNames sortUsingSelector:@selector(compare:)];
    for (NSString *nodeName in nodeNames) {
        [StringIO write:nodeName to:data];
        Node *node = [nodes objectForKey:nodeName];
        [node writeToData:data];
    }
    
    char header[TREE_HEADER_LENGTH + 1];
    sprintf(header, "TreeV%03d", CURRENT_TREE_VERSION);
    NSMutableData *completeData = [[[NSMutableData alloc] init] autorelease];
    [completeData appendBytes:header length:TREE_HEADER_LENGTH];
    
    [completeData appendBytes:[data bytes] length:[data length]];
    return completeData;
}
- (BOOL)ctimeMatchesStat:(struct stat *)st {
    return st->st_ctimespec.tv_sec == ctime_sec && st->st_ctimespec.tv_nsec == ctime_nsec;
}
- (uint64_t)aggregateUncompressedDataSize {
    //FIXME: This doesn't include the size of the ACL.
    uint64_t ret = xattrsSize;
    for (Node *node in [nodes allValues]) {
        ret += [node uncompressedDataSize];
    }
    return ret;
}

#pragma mark NSObject
- (BOOL)isEqual:(id)object {
    if (![object isKindOfClass:[Tree class]]) {
        return NO;
    }
    Tree *other = (Tree *)object;
    BOOL ret = (treeVersion == [other treeVersion]
    && xattrsAreCompressed == [other xattrsAreCompressed]
    && [NSObject equalObjects:xattrsBlobKey and:[other xattrsBlobKey]]
    && xattrsSize == [other xattrsSize]
    && aclIsCompressed == [other aclIsCompressed]
    && [NSObject equalObjects:aclBlobKey and:[other aclBlobKey]]
    && uid == [other uid]
    && gid == [other gid]
    && mode == [other mode]
    && mtime_sec == [other mtime_sec]
    && mtime_nsec == [other mtime_nsec]
    && flags == [other flags]
    && finderFlags == [other finderFlags]
    && extendedFinderFlags == [other extendedFinderFlags]
    && st_dev == [other st_dev]
    && st_ino == [other st_ino]
    && st_nlink == [other st_nlink]
    && st_rdev == [other st_rdev]
    && ctime_sec == [other ctime_sec]
    && ctime_nsec == [other ctime_nsec]
    && createTime_sec == [other createTime_sec]
    && createTime_nsec == [other createTime_nsec]
    && [missingNodes isEqual:[other missingNodes]]
    && st_blocks == [other st_blocks]
    && st_blksize == [other st_blksize]
    && [nodes isEqual:[other nodes]]);
    return ret;
}
- (NSUInteger)hash {
    return (NSUInteger)treeVersion + [nodes hash];
}
@end

@implementation Tree (internal)
- (BOOL)readHeader:(BufferedInputStream *)is error:(NSError **)error {
    BOOL ret = NO;
    unsigned char *buf = (unsigned char *)malloc(TREE_HEADER_LENGTH);
    if (![is readExactly:TREE_HEADER_LENGTH into:buf error:error]) {
        goto readHeader_error;
    }
    NSString *header = [[[NSString alloc] initWithBytes:buf length:TREE_HEADER_LENGTH encoding:NSASCIIStringEncoding] autorelease];
    if (![header hasPrefix:@"TreeV"] || [header length] < 6) {
        SETNSERROR([Tree errorDomain], ERROR_INVALID_OBJECT_VERSION, @"invalid Tree header: %@", header);
        goto readHeader_error;
    }
    treeVersion = [[header substringFromIndex:5] intValue];
    if (treeVersion < 10) {
        SETNSERROR([Tree errorDomain], ERROR_INVALID_OBJECT_VERSION, @"invalid Tree header: %@", header);
        goto readHeader_error;
    }
    if (treeVersion == 13) {
        SETNSERROR([Tree errorDomain], ERROR_INVALID_OBJECT_VERSION, @"invalid Tree version 13");
        goto readHeader_error;
    }
    ret = YES;
readHeader_error:
    free(buf);
    return ret;
}
@end
