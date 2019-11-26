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



#import "ReflogEntry.h"
#import "DictNode.h"
#import "BlobKey.h"
#import "BooleanNode.h"
#import "StringNode.h"


@implementation ReflogEntry
- (id)initWithId:(NSString *)theReflogId plist:(DictNode *)thePlist error:(NSError **)error {
    if (self = [super init]) {
        reflogId = [theReflogId retain];
        double timeInterval = [reflogId doubleValue];
        createdDate = [[NSDate alloc] initWithTimeIntervalSinceReferenceDate:timeInterval];
        
        if ([thePlist containsKey:@"oldHeadSHA1"]) {
            BOOL oldHeadStretchKey = [[thePlist booleanNodeForKey:@"oldHeadStretchKey"] booleanValue];
            NSString *oldHeadSHA1 = [[thePlist stringNodeForKey:@"oldHeadSHA1"] stringValue];
            oldHeadBlobKey = [[BlobKey alloc] initWithSHA1:oldHeadSHA1 storageType:StorageTypeS3 stretchEncryptionKey:oldHeadStretchKey compressionType:BlobKeyCompressionNone error:error];
            if (oldHeadBlobKey == nil) {
                [self release];
                return nil;
            }
        }
        BOOL newHeadStretchKey = [[thePlist booleanNodeForKey:@"newHeadStretchKey"] booleanValue];
        NSString *newHeadSHA1 = [[thePlist stringNodeForKey:@"newHeadSHA1"] stringValue];
        newHeadBlobKey = [[BlobKey alloc] initWithSHA1:newHeadSHA1 storageType:StorageTypeS3 stretchEncryptionKey:newHeadStretchKey compressionType:BlobKeyCompressionNone error:error];
        if (newHeadBlobKey == nil) {
            [self release];
            return nil;
        }
        
        isRewrite = [[thePlist booleanNodeForKey:@"isRewrite"] booleanValue];
        
        packSHA1 = [[[thePlist stringNodeForKey:@"packSHA1"] stringValue] retain];
    }
    return self;
}
- (void)dealloc {
    [createdDate release];
    [reflogId release];
    [oldHeadBlobKey release];
    [newHeadBlobKey release];
    [packSHA1 release];
    [super dealloc];
}

- (NSDate *)createdDate {
    return createdDate;
}
- (NSString *)reflogId {
    return reflogId;
}
- (BlobKey *)oldHeadBlobKey {
    return oldHeadBlobKey;
}
- (BlobKey *)newHeadBlobKey {
    return newHeadBlobKey;
}
- (BOOL)isRewrite {
    return isRewrite;
}
- (NSString *)packSHA1 {
    return packSHA1;
}
@end
