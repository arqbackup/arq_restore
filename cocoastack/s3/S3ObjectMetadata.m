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

#import "S3ObjectMetadata.h"
#import "RFC822.h"
#import "StringIO.h"
#import "DateIO.h"
#import "IntegerIO.h"

@implementation S3ObjectMetadata
- (id)initWithS3BucketName:(NSString *)s3BucketName node:(NSXMLNode *)node error:(NSError **)error {
	if (error != NULL) {
		*error = nil;
	}
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	if (self = [super init]) {
		NSArray *nodes = [node nodesForXPath:@"Key" error:error];
        if (!nodes) {
			goto init_error;
        }
		NSXMLNode *keyNode = [nodes objectAtIndex:0];
		path = [[NSString alloc] initWithFormat:@"/%@/%@", s3BucketName, [keyNode stringValue]];
		nodes = [node nodesForXPath:@"LastModified" error:error];
        if (!nodes) {
			goto init_error;
        }
		NSXMLNode *lastModifiedNode = [nodes objectAtIndex:0];
        lastModified = [[RFC822 dateFromString:[lastModifiedNode stringValue] error:error] retain];
        if (lastModified == nil) {
			goto init_error;
        }
		nodes = [node nodesForXPath:@"Size" error:error];
        if (!nodes) {
			goto init_error;
        }
		NSXMLNode *sizeNode = [nodes objectAtIndex:0];
		NSNumberFormatter *numberFormatter = [[[NSNumberFormatter alloc] init] autorelease];
		size = [[numberFormatter numberFromString:[sizeNode stringValue]] longValue];
        nodes = [node nodesForXPath:@"StorageClass" error:error];
        if (!nodes) {
            goto init_error;
        }
        if ([nodes count] == 0) {
            storageClass = @"STANDARD";
        } else {
            NSXMLNode *storageClassNode = [nodes objectAtIndex:0];
            storageClass = [[storageClassNode stringValue] retain];
        }
		goto init_done;
	init_error:
		[self release];
		self = nil;
		goto init_done;
	}
init_done:
	if (error != NULL) {
		[*error retain];
	}
	[pool drain];
	if (error != NULL) {
		[*error autorelease];
	}
	return self;
}
- (id)initWithPath:(NSString *)thePath lastModified:(NSDate *)theLastModified size:(long)theSize storageClass:(NSString *)theStorageClass {
    if (self = [super init]) {
        path = [thePath retain];
        lastModified = [theLastModified retain];
        size = theSize;
        storageClass = [theStorageClass retain];
    }
    return self;
}
- (id)initFromBufferedInputStream:(BufferedInputStream *)theBIS error:(NSError **)error {
    if (self = [super init]) {
        int64_t theSize = 0;
        BOOL ret = [StringIO read:&path from:theBIS error:error]
        && [DateIO read:&lastModified from:theBIS error:error]
        && [IntegerIO readInt64:&theSize from:theBIS error:error]
        && [StringIO read:&storageClass from:theBIS error:error];
        [path retain];
        [lastModified retain];
        size = (long)theSize;
        [storageClass retain];
        if (!ret) {
            [self release];
            return nil;
        }
    }
    return self;
}
- (void)dealloc {
	[path release];
	[lastModified release];
    [storageClass release];
	[super dealloc];
}
- (BOOL)writeToBufferedOutputStream:(BufferedOutputStream *)theBOS error:(NSError **)error {
    return [StringIO write:path to:theBOS error:error]
    && [DateIO write:lastModified to:theBOS error:error]
    && [IntegerIO writeInt64:(int64_t)size to:theBOS error:error]
    && [StringIO write:storageClass to:theBOS error:error];
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
