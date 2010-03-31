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

#import "RFC2616DateFormatter.h"
#import "NSError_S3.h"
#import "S3AuthorizationProvider.h"
#import "S3AuthorizationParameters.h"
#import "S3Lister.h"
#import "SetNSError.h"
#import "HTTPRequest.h"
#import "HTTPResponse.h"
#import "HTTP.h"
#import "S3Service.h"
#import "S3Request.h"
#import "ServerBlob.h"

@interface S3Lister (internal)
- (BOOL)getWithMax:(int)max error:(NSError **)error;
@end

@implementation S3Lister
- (id)initWithS3AuthorizationProvider:(S3AuthorizationProvider *)theSAP useSSL:(BOOL)isUseSSL retryOnNetworkError:(BOOL)retry max:(int)theMax prefix:(NSString *)thePrefix receiver:(id)theReceiver {
	if (self = [super init]) {
        dateFormatter = [[RFC2616DateFormatter alloc] init];
		sap = [theSAP retain];
        useSSL = isUseSSL;
        retryOnNetworkError = retry;
		maxRequested = theMax;
		received = 0;
		isTruncated = YES;
		prefix = [thePrefix copy];
		receiver = [theReceiver retain];
		marker = nil;
	}
	return self;
}
- (void)dealloc {
    [dateFormatter release];
	[sap release];
	[prefix release];
	[receiver release];
    [marker release];
	[super dealloc];
}
- (BOOL)listObjects:(NSError **)error {
	if (error != NULL) {
		*error = nil;
	}
    BOOL ret = YES;
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	while (isTruncated) {
		if (maxRequested < 0) {
            if (![self getWithMax:-1 error:error]) {
                ret = NO;
                break;
            }
		} else {
			if (![self getWithMax:(maxRequested - received) error:error]) {
                ret = NO;
                break;
            }
		}
	}
	if (!ret && error != NULL) {
		[*error retain];
	}
    [pool drain];
	if (!ret && error != NULL) {
		[*error autorelease];
	}
    return ret;
}
@end

@implementation S3Lister (internal)
- (BOOL)getWithMax:(int)max error:(NSError **)error {
	if (![prefix hasPrefix:@"/"]) {
        SETNSERROR([S3Service errorDomain], -1, @"path must start with /");
        return NO;
	}
	NSString *strippedPrefix = [prefix substringFromIndex:1];
	NSRange range = [strippedPrefix rangeOfString:@"/"];
	if (range.location == NSNotFound) {
        SETNSERROR([S3Service errorDomain], -1, @"path must contain S3 bucket name plus path");
        return NO;
	}
	NSString *s3BucketName = [strippedPrefix substringToIndex:range.location];
	NSString *pathPrefix = [strippedPrefix substringFromIndex:range.location];
	NSMutableString *queryString = [NSMutableString stringWithFormat:@"?prefix=%@", [[pathPrefix substringFromIndex:1] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
	if (maxRequested > 0) {
		[queryString appendString:[NSString stringWithFormat:@"&max-keys=%d", maxRequested]];
	}
	if (marker != nil) {
        NSAssert([marker hasPrefix:s3BucketName], @"marker must start with S3 bucket name");
        NSString *suffix = [marker substringFromIndex:([s3BucketName length] + 1)];
		[queryString appendString:[NSString stringWithFormat:@"&marker=%@", [suffix stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]]];
	}
    
    S3Request *s3r = [[S3Request alloc] initWithMethod:@"GET" path:[NSString stringWithFormat:@"/%@/", s3BucketName] queryString:queryString authorizationProvider:sap useSSL:useSSL retryOnNetworkError:retryOnNetworkError];
    ServerBlob *sb = [s3r newServerBlob:error];
    [s3r release];
    if (sb == nil) {
        return NO;
    }
    NSData *data = [sb slurp:error];
    [sb release];
    if (data == nil) {
        return NO;
    }
    NSXMLDocument *xmlDoc = [[[NSXMLDocument alloc] initWithData:data options:0 error:error] autorelease];
    if (!xmlDoc) {
        return NO;
    }
    NSString *lastPath = nil;
    NSXMLElement *rootElement = [xmlDoc rootElement];
    NSArray *isTruncatedNodes = [rootElement nodesForXPath:@"//ListBucketResult/IsTruncated" error:error];
    if (!isTruncatedNodes || [isTruncatedNodes count] == 0) {
        return NO;
    }
    isTruncated = [[[isTruncatedNodes objectAtIndex:0] stringValue] isEqualToString:@"true"];
    NSArray *objects = [rootElement nodesForXPath:@"//ListBucketResult/Contents" error:error];
    if (!objects) {
        return NO;
    }
    for (NSXMLNode *objectNode in objects) {
        S3ObjectMetadata *md = [[S3ObjectMetadata alloc] initWithS3BucketName:s3BucketName node:objectNode error:error];
        if (!md) {
            return NO;
        }
        if (![receiver receiveS3ObjectMetadata:md error:error]) {
            [md release];
            return NO;
        }
        lastPath = [[[md path] retain] autorelease];
        [md release];
        received++;
        if (maxRequested > 0 && received >= maxRequested) {
            isTruncated = NO;
            break;
        }
    }
    if (lastPath != nil) {
        [marker release];
        marker = [[lastPath substringFromIndex:1] retain];
    }
    return YES;
}
@end
