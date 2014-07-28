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


#import "RFC2616DateFormatter.h"
#import "S3AuthorizationProvider.h"
#import "S3Lister.h"
#import "HTTP.h"
#import "S3Service.h"
#import "S3Request.h"


@implementation S3Lister
- (id)initWithS3AuthorizationProvider:(S3AuthorizationProvider *)theSAP endpoint:(NSURL *)theEndpoint prefix:(NSString *)thePrefix delimiter:(NSString *)theDelimiter receiver:(id)theReceiver {
	if (self = [super init]) {
        dateFormatter = [[RFC2616DateFormatter alloc] init];
		sap = [theSAP retain];
        endpoint = [theEndpoint retain];
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
    [endpoint release];
	[sap release];
	[prefix release];
    [delimiter release];
	[receiver release];
    [marker release];
    [foundPrefixes release];
	[super dealloc];
}
- (BOOL)listObjectsWithTargetConnectionDelegate:(id<TargetConnectionDelegate>)theDelegate error:(NSError **)error {
	if (error != NULL) {
		*error = nil;
	}
    BOOL ret = YES;
    
    NSAutoreleasePool *pool = nil;
	while (isTruncated) {
        [pool drain];
        pool = [[NSAutoreleasePool alloc] init];
        if (![self getWithTargetConnectionDelegate:theDelegate error:error]) {
            ret = NO;
            break;
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
- (NSArray *)foundPrefixes {
    return foundPrefixes;
}
              
#pragma mark internal
- (BOOL)getWithTargetConnectionDelegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error {
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
	NSMutableString *queryString = [NSMutableString stringWithFormat:@"prefix=%@", [[pathPrefix substringFromIndex:1] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    if (delimiter != nil) {
        [queryString appendString:@"&delimiter="];
        [queryString appendString:[delimiter stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    }
	if (marker != nil) {
        NSAssert([marker hasPrefix:s3BucketName], @"marker must start with S3 bucket name");
        NSString *suffix = [marker substringFromIndex:([s3BucketName length] + 1)];
		[queryString appendString:[NSString stringWithFormat:@"&marker=%@", [suffix stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]]];
	}
    
    S3Request *s3r = [[[S3Request alloc] initWithMethod:@"GET" endpoint:endpoint path:[NSString stringWithFormat:@"/%@/", s3BucketName] queryString:queryString authorizationProvider:sap error:error] autorelease];
    if (s3r == nil) {
        return NO;
    }
    NSData *response = [s3r dataWithTargetConnectionDelegate:theDelegate error:error];
    if (response == nil) {
        return NO;
    }
    NSError *myError = nil;
    NSArray *listBucketResultContents = [self parseXMLResponse:response s3BucketName:s3BucketName error:&myError];
    if (listBucketResultContents == nil && myError == nil) {
        [NSThread sleepForTimeInterval:0.2];
        listBucketResultContents = [self parseXMLResponse:response s3BucketName:s3BucketName error:&myError];
    }
    if (listBucketResultContents == nil) {
        if (myError == nil) {
            myError = [NSError errorWithDomain:[S3Service errorDomain] code:-1 description:@"Failed to parse ListBucketResult XML response"];
        }
        SETERRORFROMMYERROR;
        if (error != NULL) {
            HSLogError(@"error getting //ListBucketResult/Contents nodes: %@", *error);
        }
        return NO;
    }
    if (listBucketResultContents == nil) {
        return NO;
    }
    
    NSString *lastPath = nil;

    for (NSXMLNode *objectNode in listBucketResultContents) {
        S3ObjectMetadata *md = [[S3ObjectMetadata alloc] initWithS3BucketName:s3BucketName node:objectNode error:error];
        if (!md) {
            return NO;
        }
        if (![receiver receiveS3ObjectMetadata:md error:error]) {
            [md release];
            if (error != NULL) {
                HSLogError(@"error receiving object metadata: %@", *error);
            }
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

- (NSArray *)parseXMLResponse:(NSData *)response s3BucketName:(NSString *)s3BucketName error:(NSError **)error {
    NSError *myError = nil;
    NSXMLDocument *xmlDoc = [[[NSXMLDocument alloc] initWithData:response options:0 error:&myError] autorelease];
    if (!xmlDoc) {
        SETNSERROR([S3Service errorDomain], [myError code], @"error parsing List Objects XML response: %@", myError);
        return NO;
    }
    NSXMLElement *rootElement = [xmlDoc rootElement];
    NSArray *isTruncatedNodes = [rootElement nodesForXPath:@"//ListBucketResult/IsTruncated" error:&myError];
    if (isTruncatedNodes == nil) {
        HSLogError(@"nodesForXPath: %@", myError);
        SETERRORFROMMYERROR;
        return NO;
    }
    if ([isTruncatedNodes count] == 0) {
        isTruncated = NO;
    } else {
        isTruncated = [[[isTruncatedNodes objectAtIndex:0] stringValue] isEqualToString:@"true"];
    }
    if (delimiter != nil) {
        NSArray *prefixNodes = [rootElement nodesForXPath:@"//ListBucketResult/CommonPrefixes/Prefix" error:error];
        if (prefixNodes == nil) {
            if (error != NULL) {
                HSLogError(@"error getting //ListBucketResult/CommonPrefixes/Prefix nodes: %@", *error);
            }
            return NO;
        }
        for (NSXMLNode *prefixNode in prefixNodes) {
            NSString *thePrefix = [prefixNode stringValue];
            thePrefix = [thePrefix substringToIndex:([thePrefix length] - 1)];
            [foundPrefixes addObject:[NSString stringWithFormat:@"/%@/%@", s3BucketName, thePrefix]];
        }
    }
    return [rootElement nodesForXPath:@"//ListBucketResult/Contents" error:error];
}
@end
