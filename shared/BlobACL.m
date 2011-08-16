/*
 Copyright (c) 2009-2011, Stefan Reitshamer http://www.haystacksoftware.com
 
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

#import "BlobACL.h"

@implementation BlobACL
+ (NSString *)s3NameForBlobACL:(int)blobACL {
	switch(blobACL) {
		case PUBLIC_READ:
			return @"public-read";
		case PUBLIC_READ_WRITE:
			return @"public-read-write";
		case AUTHENTICATED_READ:
			return @"authenticated-read";
		default:
			return @"private";
	}
}
+ (NSString *)displayNameForBlobACL:(int)blobACL {
    switch(blobACL) {
		case PUBLIC_READ:
			return @"Public (unlisted)";
		case PUBLIC_READ_WRITE:
			return @"Public read/write";
		case AUTHENTICATED_READ:
			return @"Authenticated Read";
		default:
			return @"Private";
	}
}
+ (int)blobACLForS3Name:(NSString *)s3ACLName {
    if (!s3ACLName) {
        return 0;
    }
    if ([s3ACLName caseInsensitiveCompare:@"public-read"] == NSOrderedSame) {
        return PUBLIC_READ;
    }
    if ([s3ACLName caseInsensitiveCompare:@"public-read-write"] == NSOrderedSame) {
        return PUBLIC_READ_WRITE;
    }
    if ([s3ACLName caseInsensitiveCompare:@"authenticated-read"] == NSOrderedSame) {
        return AUTHENTICATED_READ;
    }
    if ([s3ACLName caseInsensitiveCompare:@"private"] == NSOrderedSame) {
        return PRIVATE;
    }
    return 0;
}
@end

