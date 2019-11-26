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



#include <sys/stat.h>
#import "Node.h"
#import "BooleanIO.h"
#import "IntegerIO.h"
#import "StringIO.h"
#import "BufferedInputStream.h"
#import "BlobKey.h"
#import "NSObject_extra.h"
#import "Tree.h"
#import "BlobKeyIO.h"


@implementation Node
@synthesize isTree, treeContainsMissingItems, uncompressedDataSize, xattrsBlobKey, xattrsSize, aclBlobKey, uid, gid, mode, mtime_sec, mtime_nsec, flags, finderFlags, extendedFinderFlags, finderFileType, finderFileCreator, isFileExtensionHidden, st_dev, treeVersion, st_rdev;
@synthesize ctime_sec, ctime_nsec, createTime_sec, createTime_nsec, st_nlink, st_ino, st_blocks, st_blksize;
@dynamic treeBlobKey, dataBlobKeys;


- (id)initWithInputStream:(BufferedInputStream *)is treeVersion:(int)theTreeVersion error:(NSError **)error {
    if (self = [super init]) {
        treeVersion = theTreeVersion;
        dataBlobKeys = [[NSMutableArray alloc] init];

        if (![BooleanIO read:&isTree from:is error:error]) {
            [self release];
            return nil;
        }
        
        if (theTreeVersion >= 18) {
            if (![BooleanIO read:&treeContainsMissingItems from:is error:error]) {
                [self release];
                return nil;
            }
        }
        
        BlobKeyCompressionType dataCompressionType = BlobKeyCompressionNone;
        BlobKeyCompressionType xattrsCompressionType = BlobKeyCompressionNone;
        BlobKeyCompressionType aclCompressionType = BlobKeyCompressionNone;
        if (treeVersion >= 12 && treeVersion <= 18) {
            BOOL dataAreCompressed = NO;
            BOOL xattrsAreCompressed = NO;
            BOOL aclIsCompressed = NO;
            if (![BooleanIO read:&dataAreCompressed from:is error:error]
                || ![BooleanIO read:&xattrsAreCompressed from:is error:error]
                || ![BooleanIO read:&aclIsCompressed from:is error:error]) {
                [self release];
                return nil;
            }
            dataCompressionType = dataAreCompressed ? BlobKeyCompressionGzip : BlobKeyCompressionNone;
            xattrsCompressionType = xattrsAreCompressed ? BlobKeyCompressionGzip : BlobKeyCompressionNone;
            aclCompressionType = aclIsCompressed ? BlobKeyCompressionGzip : BlobKeyCompressionNone;
        }
        if (treeVersion >= 19) {
            int32_t theDataCompressionType = 0;
            int32_t theXattrsCompressionType = 0;
            int32_t theAclCompressionType = 0;
            if (![IntegerIO readInt32:&theDataCompressionType from:is error:error]
                || ![IntegerIO readInt32:&theXattrsCompressionType from:is error:error]
                || ![IntegerIO readInt32:&theAclCompressionType from:is error:error]) {
                [self release];
                return nil;
            }
            dataCompressionType = (BlobKeyCompressionType)theDataCompressionType;
            xattrsCompressionType = (BlobKeyCompressionType)theXattrsCompressionType;
            aclCompressionType = (BlobKeyCompressionType)theAclCompressionType;
        }
        
        int dataBlobKeysCount;
        if (![IntegerIO readInt32:&dataBlobKeysCount from:is error:error]) {
            [self release];
            return nil;
        }
        for (int i = 0; i < dataBlobKeysCount; i++) {
            BlobKey *dataBlobKey = nil;
            if (![BlobKeyIO read:&dataBlobKey from:is treeVersion:treeVersion compressionType:dataCompressionType error:error]) {
                [self release];
                return nil;
            }
            [dataBlobKeys addObject:dataBlobKey];
        }
        if (![IntegerIO readUInt64:&uncompressedDataSize from:is error:error]) {
            [self release];
            return nil;
        }
        
        // As of Tree version 18 thumbnailBlobKey and previewBlobKey have been removed. They were never used.
        if (theTreeVersion < 18) {
            BlobKey *theThumbnailBlobKey = nil;
            BlobKey *thePreviewBlobKey = nil;
            if (![BlobKeyIO read:&theThumbnailBlobKey from:is treeVersion:treeVersion compressionType:BlobKeyCompressionNone error:error]
                || ![BlobKeyIO read:&thePreviewBlobKey from:is treeVersion:treeVersion compressionType:BlobKeyCompressionNone error:error]) {
                [self release];
                return nil;
            }
        }
        
        BOOL ret = [BlobKeyIO read:&xattrsBlobKey from:is treeVersion:treeVersion compressionType:xattrsCompressionType error:error]
        && [IntegerIO readUInt64:&xattrsSize from:is error:error]
        && [BlobKeyIO read:&aclBlobKey from:is treeVersion:treeVersion compressionType:aclCompressionType error:error]
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
        [xattrsBlobKey retain];
        [aclBlobKey retain];
        [finderFileType retain];
        [finderFileCreator retain];
        if (!ret) {
            [self release];
            return nil;
        }
        
        // If any BlobKey has a nil sha1, drop it.
        
        if ([xattrsBlobKey sha1] == nil) {
            [xattrsBlobKey release];
            xattrsBlobKey = nil;
        }
        if ([aclBlobKey sha1] == nil) {
            [aclBlobKey release];
            aclBlobKey = nil;
        }
    }
    return self;
}
- (void)dealloc {
	[dataBlobKeys release];
	[xattrsBlobKey release];
	[aclBlobKey release];
	[finderFileType release];
	[finderFileCreator release];
	[super dealloc];
}
- (BlobKey *)treeBlobKey {
    NSAssert(isTree, @"must be a Tree");
    return [dataBlobKeys objectAtIndex:0];
}
- (NSArray *)dataBlobKeys {
    return dataBlobKeys;
}

- (void)writeToData:(NSMutableData *)data {
    [BooleanIO write:isTree to:data];
    [BooleanIO write:treeContainsMissingItems to:data];
    BlobKeyCompressionType dataCompressionType = [dataBlobKeys count] == 0 ? BlobKeyCompressionNone : [[dataBlobKeys objectAtIndex:0] compressionType];
    [IntegerIO writeInt32:(int32_t)dataCompressionType to:data];
    [IntegerIO writeInt32:(int32_t)[xattrsBlobKey compressionType] to:data];
    [IntegerIO writeInt32:(int32_t)[aclBlobKey compressionType] to:data];
    [IntegerIO writeInt32:(int32_t)[dataBlobKeys count] to:data];
    for (BlobKey *dataBlobKey in dataBlobKeys) {
        NSAssert([dataBlobKey compressionType] == dataCompressionType, @"all dataBlobKeys must have same compression type");
        [BlobKeyIO write:dataBlobKey to:data];
    }
    [IntegerIO writeUInt64:uncompressedDataSize to:data];
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


#pragma mark NSObject
- (BOOL)isEqual:(id)object {
    if (![object isKindOfClass:[Node class]]) {
        return NO;
    }
    Node *other = (Node *)object;
    if (treeVersion != [other treeVersion]) {
        return NO;
    }
    if (isTree != [other isTree]) {
        return NO;
    }
    if (uncompressedDataSize != [other uncompressedDataSize]) {
        return NO;
    }
    if (![dataBlobKeys isEqualToArray:[other dataBlobKeys]]) {
        return NO;
    }
    if (![NSObject equalObjects:xattrsBlobKey and:[other xattrsBlobKey]]) {
        return NO;
    }
    if (xattrsSize != [other xattrsSize]) {
        return NO;
    }
    if (![NSObject equalObjects:aclBlobKey and:[other aclBlobKey]]) {
        return NO;
    }
    if (uid != [other uid]) {
        return NO;
    }
    if (gid != [other gid]) {
        return NO;
    }
    if (mode != [other mode]) {
        return NO;
    }
    if (mtime_sec != [other mtime_sec]) {
        return NO;
    }
    if (mtime_nsec != [other mtime_nsec]) {
        return NO;
    }
    if (flags != [other flags]) {
        return NO;
    }
    if (finderFlags != [other finderFlags]) {
        return NO;
    }
    if (extendedFinderFlags != [other extendedFinderFlags]) {
        return NO;
    }
    if (![NSObject equalObjects:finderFileType and:[other finderFileType]]) {
        return NO;
    }
    if (![NSObject equalObjects:finderFileCreator and:[other finderFileCreator]]) {
        return NO;
    }
    if (st_dev != [other st_dev]) {
        return NO;
    }
    if (st_ino != [other st_ino]) {
        return NO;
    }
    if (st_nlink != [other st_nlink]) {
        return NO;
    }
    if (st_rdev != [other st_rdev]) {
        return NO;
    }
    if (ctime_sec != [other ctime_sec]) {
        return NO;
    }
    if (ctime_nsec != [other ctime_nsec]) {
        return NO;
    }
    if (createTime_sec != [other createTime_sec]) {
        return NO;
    }
    if (createTime_nsec != [other createTime_nsec]) {
        return NO;
    }
    if (st_blocks != [other st_blocks]) {
        return NO;
    }
    if (st_blksize != [other st_blksize]) {
        return NO;
    }
    return YES;
}
- (NSUInteger)hash {
    return (NSUInteger)treeVersion + [dataBlobKeys hash];
}
@end
