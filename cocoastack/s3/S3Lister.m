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



#import "RFC2616DateFormatter.h"
#import "S3AuthorizationProvider.h"
#import "S3Lister.h"
#import "HTTP.h"
#import "S3Service.h"
#import "S3Request.h"
#import "Item.h"
#import "RFC822.h"
#import "TargetConnection.h"


@implementation S3Lister
- (id)initWithS3AuthorizationProvider:(id <S3AuthorizationProvider>)theSAP
                             endpoint:(NSURL *)theEndpoint
                                 path:(NSString *)thePath
                            delimiter:(NSString *)theDelimiter
             targetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD {
    if (self = [super init]) {
        sap = [theSAP retain];
        endpoint = [theEndpoint retain];
		path = [thePath retain];
        delimiter = [theDelimiter retain];
        targetConnectionDelegate = theTCD;

        numberFormatter = [[NSNumberFormatter alloc] init];
        
		isTruncated = YES;
    }
    return self;
}
- (void)dealloc {
    [endpoint release];
	[sap release];
    [path release];
    [delimiter release];
    [numberFormatter release];
    [s3BucketName release];
    [s3Path release];
    [escapedS3ObjectPathPrefix release];
    [marker release];
	[super dealloc];
}
- (NSDictionary *)itemsByName:(NSError **)error {
    if (![path hasPrefix:@"/"]) {
        SETNSERROR([S3Service errorDomain], -1, @"path must start with '/'");
        return nil;
    }
    NSString *strippedPrefix = [path substringFromIndex:1];
    NSRange range = [strippedPrefix rangeOfString:@"/"];
    if (range.location == NSNotFound) {
        SETNSERROR([S3Service errorDomain], -1, @"path must contain S3 bucket name plus object path");
        return nil;
    }
    s3BucketName = [[strippedPrefix substringToIndex:range.location] retain];
    s3Path = [[NSString alloc] initWithFormat:@"/%@/", s3BucketName];
    escapedS3ObjectPathPrefix = [[[strippedPrefix substringFromIndex:(range.location + 1)] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding] retain];
    
    
    NSMutableDictionary *ret = [NSMutableDictionary dictionary];
    
    NSAutoreleasePool *pool = nil;
	while (isTruncated) {
        [pool drain];
        pool = [[NSAutoreleasePool alloc] init];
        NSArray *items = [self nextPage:error];
        if (items == nil) {
            ret = nil;
            break;
        }
        for (Item *item in items) {
            [ret setObject:item forKey:item.name];
        }
    }
    
    if (ret == nil && error != NULL) {
        [*error retain];
    }
    [pool drain];
    if (ret == nil && error != NULL) {
        [*error autorelease];
    }
    return ret;
}


#pragma mark internal
- (NSArray *)nextPage:(NSError **)error {
    if (targetConnectionDelegate != nil && ![targetConnectionDelegate targetConnectionShouldRetryOnTransientError:error]) {
        return nil;
    }
    
    NSMutableString *queryString = [NSMutableString stringWithFormat:@"prefix=%@", escapedS3ObjectPathPrefix];
    if (delimiter != nil) {
        [queryString appendFormat:@"&delimiter=%@", [delimiter stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    }
    if (marker != nil) {
        NSAssert([marker hasPrefix:s3BucketName], @"marker must start with S3 bucket name");
        NSString *suffix = [marker substringFromIndex:([s3BucketName length] + 1)];
        [queryString appendFormat:@"&marker=%@", [suffix stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    }
    [queryString appendString:@"&max-keys=500"];
    S3Request *s3r = [[[S3Request alloc] initWithMethod:@"GET" endpoint:endpoint path:[NSString stringWithFormat:@"/%@/", s3BucketName] queryString:queryString authorizationProvider:sap error:error] autorelease];
    if (s3r == nil) {
        return nil;
    }
    NSError *myError = nil;
    NSData *response = [s3r dataWithTargetConnectionDelegate:targetConnectionDelegate error:&myError];
    if (response == nil) {
        if ([myError isErrorWithDomain:[S3Service errorDomain] code:ERROR_NOT_FOUND]) {
            // minio (S3-compatible server) returns not found instead of an empty result set.
            isTruncated = NO;
            return [NSArray array];
        }
        SETERRORFROMMYERROR;
        return nil;
    }
    NSArray *foundPrefixes = nil;
    NSArray *listBucketResultContents = [self parseXMLResponse:response foundPrefixes:&foundPrefixes error:&myError];
    if (listBucketResultContents == nil && myError == nil) {
        [NSThread sleepForTimeInterval:0.2];
        listBucketResultContents = [self parseXMLResponse:response foundPrefixes:&foundPrefixes error:&myError];
    }
    if (listBucketResultContents == nil) {
        if (myError == nil) {
            myError = [[[NSError alloc] initWithDomain:[S3Service errorDomain] code:-1 description:@"Failed to parse ListBucketResult XML response"] autorelease];
        }
        HSLogDebug(@"response was %@", [[[NSString alloc] initWithData:response encoding:NSUTF8StringEncoding] autorelease]);
        HSLogError(@"error getting //ListBucketResult/Contents nodes: %@", myError);
        SETERRORFROMMYERROR;
        return nil;
    }
    
    NSString *lastObjectPath = nil;
    NSMutableArray *ret = [NSMutableArray array];
    
    for (NSString *foundPrefix in foundPrefixes) {
        Item *item = [[[Item alloc] init] autorelease];
        item.isDirectory = YES;
        item.name = [foundPrefix lastPathComponent];
        [ret addObject:item];
    }
    
    for (NSXMLNode *objectNode in listBucketResultContents) {
        Item *item = [[[Item alloc] init] autorelease];
        item.isDirectory = NO;
        
        NSXMLNode *keyNode = [[objectNode nodesForXPath:@"Key" error:error] lastObject];
        if (keyNode == nil) {
            return nil;
        }
        NSString *objectPath = [NSString stringWithFormat:@"/%@/%@", s3BucketName, [keyNode stringValue]];
        item.name = [objectPath lastPathComponent];
        lastObjectPath = objectPath;
        
        NSXMLNode *lastModifiedNode = [[objectNode nodesForXPath:@"LastModified" error:error] lastObject];
        if (lastModifiedNode == nil) {
            return nil;
        }
        NSDate *lastModified = [RFC822 dateFromString:[lastModifiedNode stringValue] error:error];
        if (lastModified == nil) {
            return nil;
        }
        item.fileLastModified = lastModified;
        
        NSXMLNode *sizeNode = [[objectNode nodesForXPath:@"Size" error:error] lastObject];
        if (sizeNode == nil) {
            return nil;
        }
        unsigned long long size = [[numberFormatter numberFromString:[sizeNode stringValue]] unsignedLongLongValue];
        item.fileSize = size;
        
        NSArray *nodes = [objectNode nodesForXPath:@"StorageClass" error:error];
        if (nodes == nil) {
            return nil;
        }
        NSString *storageClass = [[nodes lastObject] stringValue];
        if (storageClass == nil) {
            storageClass = @"STANDARD";
        }
        item.storageClass = storageClass;
        
        NSString *etag = [[[objectNode nodesForXPath:@"ETag" error:NULL] lastObject] stringValue];
        if (etag != nil) {
            if ([etag hasPrefix:@"\""] && [etag hasSuffix:@"\""]) {
                etag = [etag substringWithRange:NSMakeRange(1, [etag length] - 2)];
            }
            item.checksum = [@"md5:" stringByAppendingString:etag];
        }
        
        [ret addObject:item];
        
    }
    if (lastObjectPath != nil) {
        [marker release];
        marker = [[lastObjectPath substringFromIndex:1] retain];
    }
    return ret;
}

- (NSArray *)parseXMLResponse:(NSData *)response foundPrefixes:(NSArray **)foundPrefixes error:(NSError **)error {
    NSError *myError = nil;
    NSXMLDocument *xmlDoc = [[[NSXMLDocument alloc] initWithData:response options:0 error:&myError] autorelease];
    if (!xmlDoc) {
        HSLogDebug(@"list Objects XML data: %@", [[[NSString alloc] initWithData:response encoding:NSUTF8StringEncoding] autorelease]);
        SETNSERROR([S3Service errorDomain], [myError code], @"error parsing List Objects XML response: %@", myError);
        return nil;
    }
    NSXMLElement *rootElement = [xmlDoc rootElement];
    NSArray *isTruncatedNodes = [rootElement nodesForXPath:@"//ListBucketResult/IsTruncated" error:&myError];
    if (isTruncatedNodes == nil) {
        HSLogError(@"nodesForXPath: %@", myError);
        SETERRORFROMMYERROR;
        return nil;
    }
    if ([isTruncatedNodes count] == 0) {
        isTruncated = NO;
    } else {
        isTruncated = [[[isTruncatedNodes objectAtIndex:0] stringValue] isEqualToString:@"true"];
    }
    NSArray *prefixNodes = [rootElement nodesForXPath:@"//ListBucketResult/CommonPrefixes/Prefix" error:error];
    if (prefixNodes == nil) {
        if (error != NULL) {
            HSLogError(@"error getting //ListBucketResult/CommonPrefixes/Prefix nodes: %@", *error);
        }
        return nil;
    }
    NSMutableArray *theFoundPrefixes = [NSMutableArray array];
    for (NSXMLNode *prefixNode in prefixNodes) {
        NSString *thePrefix = [prefixNode stringValue];
        thePrefix = [thePrefix substringToIndex:([thePrefix length] - 1)];
        [theFoundPrefixes addObject:[NSString stringWithFormat:@"/%@/%@", s3BucketName, thePrefix]];
    }
    if (foundPrefixes != NULL) {
        *foundPrefixes = theFoundPrefixes;
    }
    return [rootElement nodesForXPath:@"//ListBucketResult/Contents" error:error];
}
@end
