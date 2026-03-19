/*
 Copyright (c) 2009-2026, Haystack Software LLC https://www.arqbackup.com
 
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

#import "S3ObjectMetadata.h"
#import "RFC822.h"
#import "StringIO.h"
#import "DateIO.h"
#import "IntegerIO.h"

@implementation S3ObjectMetadata
- (id)initWithS3BucketName:(NSString *)s3BucketName node:(NSXMLNode *)node error:(NSError **)error {
    if (self = [super init]) {
        NSArray *nodes = nil;
        NSXMLNode *keyNode = nil;
        NSXMLNode *lastModifiedNode = nil;
        NSXMLNode *sizeNode = nil;
        NSNumberFormatter *numberFormatter = nil;

        nodes = [node nodesForXPath:@"Key" error:error];
        if (!nodes) {
            goto init_error;
        }
        keyNode = [nodes objectAtIndex:0];
        path = [[NSString alloc] initWithFormat:@"/%@/%@", s3BucketName, [keyNode stringValue]];
        nodes = [node nodesForXPath:@"LastModified" error:error];
        if (!nodes) {
            goto init_error;
        }
        lastModifiedNode = [nodes objectAtIndex:0];
        lastModified = [RFC822 dateFromString:[lastModifiedNode stringValue] error:error];
        if (lastModified == nil) {
            goto init_error;
        }
        nodes = [node nodesForXPath:@"Size" error:error];
        if (!nodes) {
            goto init_error;
        }
        sizeNode = [nodes objectAtIndex:0];
        numberFormatter = [[NSNumberFormatter alloc] init];
        size = [[numberFormatter numberFromString:[sizeNode stringValue]] longValue];
        nodes = [node nodesForXPath:@"StorageClass" error:error];
        if (!nodes) {
            goto init_error;
        }
        if ([nodes count] == 0) {
            storageClass = @"STANDARD";
        } else {
            NSXMLNode *storageClassNode = [nodes objectAtIndex:0];
            storageClass = [storageClassNode stringValue];
        }
        goto init_done;
    init_error:
        self = nil;
    init_done:;
    }
    return self;
}
- (id)initWithPath:(NSString *)thePath lastModified:(NSDate *)theLastModified size:(long)theSize storageClass:(NSString *)theStorageClass {
    return [self initWithPath:thePath lastModified:theLastModified size:theSize storageClass:theStorageClass itemId:nil];
}
- (id)initWithPath:(NSString *)thePath lastModified:(NSDate *)theLastModified size:(long)theSize storageClass:(NSString *)theStorageClass itemId:(NSString  *)theItemId {
    if (self = [super init]) {
        path = thePath;
        lastModified = theLastModified;
        size = theSize;
        storageClass = theStorageClass;
        itemId = theItemId;
    }
    return self;
}
- (id)initFromBufferedInputStream:(BufferedInputStream *)theBIS error:(NSError **)error {
    if (self = [super init]) {
        NSString *thePath = nil;
        NSDate *theLastModified = nil;
        int64_t theSize = 0;
        NSString *theStorageClass = nil;
        NSString *theItemId = nil;
        BOOL ret = [StringIO read:&thePath from:theBIS error:error]
        && [DateIO read:&theLastModified from:theBIS error:error]
        && [IntegerIO readInt64:&theSize from:theBIS error:error]
        && [StringIO read:&theStorageClass from:theBIS error:error]
        && [StringIO read:&theItemId from:theBIS error:error];

        if (!ret) {
            return nil;
        }
        path = thePath;
        lastModified = theLastModified;
        size = (long)theSize;
        storageClass = theStorageClass;
        itemId = theItemId;
    }
    return self;
}
- (BOOL)writeToBufferedOutputStream:(BufferedOutputStream *)theBOS error:(NSError **)error {
    return [StringIO write:path to:theBOS error:error]
    && [DateIO write:lastModified to:theBOS error:error]
    && [IntegerIO writeInt64:(int64_t)size to:theBOS error:error]
    && [StringIO write:storageClass to:theBOS error:error]
    && [StringIO write:itemId to:theBOS error:error];
}
- (NSString *)path {
	return path;
}
- (NSDate *)lastModified {
	return lastModified;
}
- (long)size {
	return size;
}
- (NSString *)storageClass {
    return storageClass;
}
- (NSString *)itemId {
    return itemId;
}

#pragma mark NSObject
- (NSString *)description {
    return [NSString stringWithFormat:@"<S3ObjectMetadata: %18s; mod %@; %12ld bytes; %@", 
            [storageClass UTF8String], 
            [lastModified descriptionWithCalendarFormat:@"%Y-%m-%d %H:%M:%S" 
                                               timeZone:nil
                                                 locale:[[NSUserDefaults standardUserDefaults] dictionaryRepresentation]],
            size, 
            path];
}
@end
