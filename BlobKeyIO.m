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


#import "BlobKeyIO.h"
#import "BooleanIO.h"
#import "StringIO.h"
#import "IntegerIO.h"
#import "StorageType.h"
#import "BlobKey.h"
#import "DateIO.h"


@implementation BlobKeyIO
+ (void)write:(BlobKey *)theBlobKey to:(NSMutableData *)data {
    [StringIO write:[theBlobKey sha1] to:data];
    [BooleanIO write:[theBlobKey stretchEncryptionKey] to:data];
    [IntegerIO writeUInt32:(uint32_t)[theBlobKey storageType] to:data];
    [StringIO write:[theBlobKey archiveId] to:data];
    [IntegerIO writeUInt64:[theBlobKey archiveSize] to:data];
    [DateIO write:[theBlobKey archiveUploadedDate] to:data];
}
+ (BOOL)write:(BlobKey *)theBlobKey to:(BufferedOutputStream *)os error:(NSError **)error {
    return [StringIO write:[theBlobKey sha1] to:os error:error]
    && [BooleanIO write:[theBlobKey stretchEncryptionKey] to:os error:error]
    && [IntegerIO writeUInt32:(uint32_t)[theBlobKey storageType] to:os error:error]
    && [StringIO write:[theBlobKey archiveId] to:os error:error]
    && [IntegerIO writeUInt64:[theBlobKey archiveSize] to:os error:error]
    && [DateIO write:[theBlobKey archiveUploadedDate] to:os error:error];
}
+ (BOOL)read:(BlobKey **)theBlobKey from:(BufferedInputStream *)is treeVersion:(int)theTreeVersion compressed:(BOOL)isCompressed error:(NSError **)error {
    NSString *dataSHA1;
    BOOL stretchEncryptionKey = NO;
    StorageType storageType = StorageTypeS3;
    NSString *archiveId = nil;
    uint64_t archiveSize = 0;
    NSDate *archiveUploadedDate = nil;
    
    if (![StringIO read:&dataSHA1 from:is error:error]) {
        return NO;
    }
    if (theTreeVersion >= 14 && ![BooleanIO read:&stretchEncryptionKey from:is error:error]) {
        return NO;
    }
    if (theTreeVersion >= 17) {
        if (![IntegerIO readUInt32:&storageType from:is error:error]
            || ![StringIO read:&archiveId from:is error:error]
            || ![IntegerIO readUInt64:&archiveSize from:is error:error]
            || ![DateIO read:&archiveUploadedDate from:is error:error]) {
            [self release];
            return NO;
        }
    }
    if (dataSHA1 == nil) {
        // This BlobKeyIO class has been writing nil BlobKeys as if they weren't nil,
        // and then reading the values in and creating bogus BlobKeys.
        // If the sha1 is nil, it must have been a nil BlobKey, so we return nil here.
        *theBlobKey = nil;
    } else {
        *theBlobKey = [[[BlobKey alloc] initWithStorageType:storageType archiveId:archiveId archiveSize:archiveSize archiveUploadedDate:archiveUploadedDate sha1:dataSHA1 stretchEncryptionKey:stretchEncryptionKey compressed:isCompressed error:error] autorelease];
        if (*theBlobKey == nil) {
            return NO;
        }
    }
    return YES;
}
@end
