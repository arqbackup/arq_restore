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

#import "RFC2616DateFormatter.h"
#import "NSError_S3.h"
#import "S3AuthorizationProvider.h"
#import "S3Lister.h"
#import "SetNSError.h"
#import "HTTP.h"
#import "S3Service.h"
#import "S3Request.h"

@interface S3Lister (internal)
- (BOOL)get:(NSError **)error;
@end

@implementation S3Lister
- (id)initWithS3AuthorizationProvider:(S3AuthorizationProvider *)theSAP useSSL:(BOOL)isUseSSL retryOnTransientError:(BOOL)retry prefix:(NSString *)thePrefix delimiter:(NSString *)theDelimiter receiver:(id)theReceiver {
	if (self = [super init]) {
        dateFormatter = [[RFC2616DateFormatter alloc] init];
		sap = [theSAP retain];
        useSSL = isUseSSL;
        retryOnTransientError = retry;
		received = 0;
		isTruncated = YES;
		prefix = [thePrefix copy];
        delimiter = [theDelimiter copy];
		receiver = [theReceiver retain];
		marker = nil;
        foundPrefixes = [[NSMutableArray alloc] init];
	}
	return self;
}
- (void)dealloc {
    [dateFormatter release];
	[sap release];
	[prefix release];
    [delimiter release];
	[receiver release];
    [marker release];
    [foundPrefixes release];
	[super dealloc];
}
- (BOOL)listObjects:(NSError **)error {
	if (error != NULL) {
		*error = nil;
	}
    BOOL ret = YES;
    
    NSAutoreleasePool *pool = nil;
	while (isTruncated) {
        [pool drain];
        pool = [[NSAutoreleasePool alloc] init];
        if (![self get:error]) {
            ret = NO;
            break;
        }
	}

	if (error != NULL) {
		[*error retain];
	}
    [pool drain];
	if (error != NULL) {
		[*error autorelease];
	}
    return ret;
}
- (NSArray *)foundPrefixes {
    return foundPrefixes;
}
@end

@implementation S3Lister (internal)
- (BOOL)get:(NSError **)error {
	if (![prefix hasPrefix:@"/"]) {
        SETNSERROR([S3Service errorDomain], S3SERVICE_INVALID_PARAMETERS, @"path must start with /");
        return NO;
	}
	NSString *strippedPrefix = [prefix substringFromIndex:1];
	NSRange range = [strippedPrefix rangeOfString:@"/"];
	if (range.location == NSNotFound) {
        SETNSERROR([S3Service errorDomain], S3SERVICE_INVALID_PARAMETERS, @"path must contain S3 bucket name plus path");
        return NO;
	}
	NSString *s3BucketName = [strippedPrefix substringToIndex:range.location];
	NSString *pathPrefix = [strippedPrefix substringFromIndex:range.location];
	NSMutableString *queryString = [NSMutableString stringWithFormat:@"?prefix=%@", [[pathPrefix substringFromIndex:1] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    if (delimiter != nil) {
        [queryString appendString:@"&delimiter="];
        [queryString appendString:[delimiter stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    }
	if (marker != nil) {
        NSAssert([marker hasPrefix:s3BucketName], @"marker must start with S3 bucket name");
        NSString *suffix = [marker substringFromIndex:([s3BucketName length] + 1)];
		[queryString appendString:[NSString stringWithFormat:@"&marker=%@", [suffix stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]]];
	}
    
    S3Request *s3r = [[S3Request alloc] initWithMethod:@"GET" path:[NSString stringWithFormat:@"/%@/", s3BucketName] queryString:queryString authorizationProvider:sap useSSL:useSSL retryOnTransientError:retryOnTransientError error:error];
    if (s3r == nil) {
        return NO;
    }
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
    NSError *myError = nil;
    NSXMLDocument *xmlDoc = [[[NSXMLDocument alloc] initWithData:data options:0 error:&myError] autorelease];
    if (!xmlDoc) {
        SETNSERROR([S3Service errorDomain], [myError code], @"error parsing List Objects XML response: %@", myError);
        return NO;
    }
    NSString *lastPath = nil;
    NSXMLElement *rootElement = [xmlDoc rootElement];
    NSArray *isTruncatedNodes = [rootElement nodesForXPath:@"//ListBucketResult/IsTruncated" error:error];
    if (!isTruncatedNodes || [isTruncatedNodes count] == 0) {
        return NO;
    }
    isTruncated = [[[isTruncatedNodes objectAtIndex:0] stringValue] isEqualToString:@"true"];
    if (delimiter != nil) {
        NSArray *prefixNodes = [rootElement nodesForXPath:@"//ListBucketResult/CommonPrefixes/Prefix" error:error];
        if (prefixNodes == nil) {
            return NO;
        }
        for (NSXMLNode *prefixNode in prefixNodes) {
            NSString *thePrefix = [prefixNode stringValue];
            thePrefix = [thePrefix substringToIndex:([thePrefix length] - 1)];
            [foundPrefixes addObject:[NSString stringWithFormat:@"/%@/%@", s3BucketName, thePrefix]];
        }
    }
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
    }
    if (lastPath != nil) {
        [marker release];
        marker = [[lastPath substringFromIndex:1] retain];
    }
    return YES;
}
@end
