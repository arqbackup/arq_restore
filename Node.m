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

#include <sys/stat.h>
#import "BooleanIO.h"
#import "IntegerIO.h"
#import "StringIO.h"
#import "Node.h"
#import "InputStream.h"
#import "Blob.h"
#import "SetNSError.h"
#import "Tree.h"

@implementation Node
@synthesize isTree, dataSize, thumbnailSHA1, previewSHA1, xattrsSHA1, xattrsSize, aclSHA1, uid, gid, mode, mtime_sec, mtime_nsec, flags, finderFlags, extendedFinderFlags, finderFileType, finderFileCreator, isFileExtensionHidden, treeVersion, st_rdev;
@synthesize ctime_sec, ctime_nsec, createTime_sec, createTime_nsec, st_nlink, st_ino;
@dynamic treeSHA1, dataSHA1s;

- (id)initWithInputStream:(id <BufferedInputStream>)is treeVersion:(int)theTreeVersion error:(NSError **)error {
    if (self = [super init]) {
        treeVersion = theTreeVersion;
        dataSHA1s = [[NSMutableArray alloc] init];
        BOOL ret = NO;
        do {
            if (![BooleanIO read:&isTree from:is error:error]) {
                break;
            }
            int dataSHA1sCount;
            if (![IntegerIO readInt32:&dataSHA1sCount from:is error:error]) {
                break;
            }
            for (int i = 0; i < dataSHA1sCount; i++) {
                NSString *dataSHA1;
                if (![StringIO read:&dataSHA1 from:is error:error]) {
                    break;
                }
                [dataSHA1s addObject:dataSHA1];
            }
            ret = [IntegerIO readUInt64:&dataSize from:is error:error]
            && [StringIO read:&thumbnailSHA1 from:is error:error]
            && [StringIO read:&previewSHA1 from:is error:error]
            && [StringIO read:&xattrsSHA1 from:is error:error]
            && [IntegerIO readUInt64:&xattrsSize from:is error:error]
            && [StringIO read:&aclSHA1 from:is error:error]
            && [IntegerIO readInt32:&uid from:is error:error]
            && [IntegerIO readInt32:&gid from:is error:error]
            && [IntegerIO readInt32:&mode from:is error:error]
            && [IntegerIO readInt64:&mtime_sec from:is error:error]
            && [IntegerIO readInt64:&mtime_nsec from:is error:error]
            && [IntegerIO readInt64:&flags from:is error:error]
            && [IntegerIO readInt32:&finderFlags from:is error:error]
            && [IntegerIO readInt32:&extendedFinderFlags from:is error:error]
            && [StringIO read:&finderFileType from:is error:error]
            && [StringIO read:&finderFileCreator from:is error:error]
            && [BooleanIO read:&isFileExtensionHidden from:is error:error]
            && [IntegerIO readInt32:&st_dev from:is error:error]
            && [IntegerIO readInt32:&st_ino from:is error:error]
            && [IntegerIO readUInt32:&st_nlink from:is error:error]
            && [IntegerIO readInt32:&st_rdev from:is error:error]
            && [IntegerIO readInt64:&ctime_sec from:is error:error]
            && [IntegerIO readInt64:&ctime_nsec from:is error:error]
            && [IntegerIO readInt64:&createTime_sec from:is error:error]
            && [IntegerIO readInt64:&createTime_nsec from:is error:error]
            && [IntegerIO readInt64:&st_blocks from:is error:error]
            && [IntegerIO readUInt32:&st_blksize from:is error:error];
            [thumbnailSHA1 retain];
            [previewSHA1 retain];
            [xattrsSHA1 retain];
            [aclSHA1 retain];
            [finderFileType retain];
            [finderFileCreator retain];
        } while(0);
        if (!ret) {
            [self release];
            self = nil;
            return nil;
        }
    }
    return self;
}
- (void)dealloc {
	[dataSHA1s release];
    [thumbnailSHA1 release];
    [previewSHA1 release];
	[xattrsSHA1 release];
	[aclSHA1 release];
	[finderFileType release];
	[finderFileCreator release];
	[super dealloc];
}

- (void)writeToData:(NSMutableData *)data {
    [BooleanIO write:isTree to:data];
    [IntegerIO writeInt32:(int32_t)[dataSHA1s count] to:data];
    for (NSString *dataSHA1 in dataSHA1s) {
        [StringIO write:dataSHA1 to:data];
    }
    [IntegerIO writeUInt64:dataSize to:data];
    [StringIO write:thumbnailSHA1 to:data];
    [StringIO write:previewSHA1 to:data];
    [StringIO write:xattrsSHA1 to:data];
    [IntegerIO writeUInt64:xattrsSize to:data];
    [StringIO write:aclSHA1 to:data];
    [IntegerIO writeInt32:uid to:data];
    [IntegerIO writeInt32:gid to:data];
    [IntegerIO writeInt32:mode to:data];
    [IntegerIO writeInt64:mtime_sec to:data];
    [IntegerIO writeInt64:mtime_nsec to:data];
    [IntegerIO writeInt64:flags to:data];
    [IntegerIO writeInt32:finderFlags to:data];
    [IntegerIO writeInt32:extendedFinderFlags to:data];
    [StringIO write:finderFileType to:data];
    [StringIO write:finderFileCreator to:data];
    [BooleanIO write:isFileExtensionHidden to:data];
    [IntegerIO writeInt32:st_dev to:data];
    [IntegerIO writeInt32:st_ino to:data];
    [IntegerIO writeUInt32:st_nlink to:data];
    [IntegerIO writeInt32:st_rdev to:data];
    [IntegerIO writeInt64:ctime_sec to:data];
    [IntegerIO writeInt64:ctime_nsec to:data];
    [IntegerIO writeInt64:createTime_sec to:data];
    [IntegerIO writeInt64:createTime_nsec to:data];
    [IntegerIO writeInt64:st_blocks to:data];
    [IntegerIO writeUInt32:st_blksize to:data];
}
- (BOOL)dataMatchesStatData:(struct stat *)st {
    return (st->st_mtimespec.tv_sec == mtime_sec && st->st_mtimespec.tv_nsec == mtime_nsec & st->st_size == dataSize);
}
- (NSString *)treeSHA1 {
    NSAssert(isTree, @"must be a Tree");
    return [dataSHA1s objectAtIndex:0];
}
- (NSArray *)dataSHA1s {
    return dataSHA1s;
}
@end
