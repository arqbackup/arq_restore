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

#import "InputStream.h"
#import "RegexKitLite.h"
#import "S3Owner.h"
#import "S3Lister.h"
#import "S3AuthorizationProvider.h"
#import "S3Service.h"
#import "PathReceiver.h"
#import "DataInputStream.h"
#import "HTTP.h"
#import "Streams.h"
#import "S3ObjectReceiver.h"
#import "NSData-InputStream.h"
#import "S3Request.h"
#import "NSError_extra.h"
#import "AWSRegion.h"
#import "HTTPConnectionFactory.h"
#import "HTTPConnection.h"
#import "MD5Hash.h"
#import "S3MultiDeleteResponse.h"
#import "S3ErrorResult.h"
#import "LifecycleConfiguration.h"


NSString *kS3StorageClassStandard = @"STANDARD";
NSString *kS3StorageClassReducedRedundancy = @"REDUCED_REDUNDANCY";

/*
 * WARNING:
 * This class *must* be reentrant!
 */


@implementation S3Service
+ (NSString *)errorDomain {
    return @"S3ServiceErrorDomain";
}

- (id)initWithS3AuthorizationProvider:(S3AuthorizationProvider *)theSAP endpoint:(NSURL *)theEndpoint useAmazonRRS:(BOOL)isUseAmazonRRS {
	if (self = [super init]) {
		sap = [theSAP retain];
        endpoint = [theEndpoint retain];
        useAmazonRRS = isUseAmazonRRS;
    }
    return self;
}
- (void)dealloc {
	[sap release];
    [endpoint release];
	[super dealloc];
}

- (S3Owner *)s3OwnerWithTargetConnectionDelegate:(id<TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    if (error) {
        *error = 0;
    }
	NSXMLDocument *doc = [self listBucketsWithTargetConnectionDelegate:theDelegate error:error];
    if (!doc) {
        return nil;
    }
	NSXMLElement *rootElem = [doc rootElement];
	NSArray *idNodes = [rootElem nodesForXPath:@"//ListAllMyBucketsResult/Owner/ID" error:error];
	if (!idNodes) {
        return nil;
	}
    if ([idNodes count] == 0) {
        HSLogError(@"ListAllMyBucketsResult/Owner/ID node not found");
        return nil;
    }
	NSXMLNode *ownerIDNode = [idNodes objectAtIndex:0];
	NSArray *displayNameNodes = [rootElem nodesForXPath:@"//ListAllMyBucketsResult/Owner/DisplayName" error:error];
	if (!displayNameNodes) {
        return nil;
	}
    if ([displayNameNodes count] == 0) {
        HSLogError(@"ListAllMyBucketsResult/Owner/DisplayName not found");
        return nil;
    }
	NSXMLNode *displayNameNode = [displayNameNodes objectAtIndex:0];
    HSLogDebug(@"s3 owner ID: %@", [displayNameNode stringValue]);
	return [[[S3Owner alloc] initWithDisplayName:[displayNameNode stringValue] idString:[ownerIDNode stringValue]] autorelease];
}
- (NSArray *)s3BucketNamesWithTargetConnectionDelegate:(id<TargetConnectionDelegate>)theDelegate error:(NSError **)error {
	NSXMLDocument *doc = [self listBucketsWithTargetConnectionDelegate:theDelegate error:error];
    if (!doc) {
        return nil;
    }
	NSXMLElement *rootElem = [doc rootElement];
	NSArray *nameNodes = [rootElem nodesForXPath:@"//ListAllMyBucketsResult/Buckets/Bucket/Name" error:error];
	if (!nameNodes) {
        return nil;
    }
	NSMutableArray *bucketNames = [[[NSMutableArray alloc] init] autorelease];
	for (NSXMLNode *nameNode in nameNodes) {
		[bucketNames addObject:[nameNode stringValue]];
	}
	return bucketNames;
}
- (NSNumber *)s3BucketExists:(NSString *)s3BucketName targetConnectionDelegate:(id<TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    NSArray *s3BucketNames = [self s3BucketNamesWithTargetConnectionDelegate:theDelegate error:error];
    if (s3BucketNames == nil) {
        HSLogDebug(@"error getting S3 bucket names");
        return nil;
    }
    return [NSNumber numberWithBool:[s3BucketNames containsObject:s3BucketName]];
}
- (NSString *)locationOfS3Bucket:(NSString *)theS3BucketName targetConnectionDelegate:(id<TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://s3.amazonaws.com/%@/?location", theS3BucketName]];
    id <HTTPConnection> conn = [[[HTTPConnectionFactory theFactory] newHTTPConnectionToURL:url method:@"GET" dataTransferDelegate:nil] autorelease];
    [conn setRequestHostHeader];
    [conn setRFC822DateRequestHeader];
    if (![sap setAuthorizationRequestHeaderOnHTTPConnection:conn error:error]) {
        return nil;
    }
    HSLogDebug(@"GET %@", url);
    NSData *response = [conn executeRequest:error];
    if (response == nil) {
        return nil;
    }
    int code = [conn responseCode];
    if (code == 404) {
        SETNSERROR([S3Service errorDomain], ERROR_NOT_FOUND, @"bucket %@ not found", theS3BucketName);
        return nil;
    } else if (code != 200) {
        S3ErrorResult *errorResult = [[[S3ErrorResult alloc] initWithAction:[NSString stringWithFormat:@"GET %@", url] data:response httpErrorCode:(int)code] autorelease];
        NSError *myError = [errorResult error];
        HSLogDebug(@"GET %@ error: %@", conn, myError);
        if (error != NULL) {
            *error = myError;
        }
        return nil;
    }
    
    NSError *myError = nil;
    NSXMLDocument *xmlDoc = [[[NSXMLDocument alloc] initWithData:response options:0 error:&myError] autorelease];
    if (!xmlDoc) {
        SETNSERROR([S3Service errorDomain], [myError code], @"error parsing List Objects XML response: %@", myError);
        return nil;
    }
    NSXMLElement *rootElement = [xmlDoc rootElement];
    NSArray *nodes = [rootElement nodesForXPath:@"//LocationConstraint" error:error];
    if (!nodes) {
        return nil;
    }
    if ([nodes count] == 0) {
        SETNSERROR([S3Service errorDomain], -1, @"missing LocationConstraint in response data");
        return nil;
    }
    NSXMLNode *node = [nodes objectAtIndex:0];
    NSString *constraint = [node stringValue];
    return constraint;
}
- (NSArray *)pathsWithPrefix:(NSString *)prefix targetConnectionDelegate:(id<TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    return [self pathsWithPrefix:prefix delimiter:nil targetConnectionDelegate:theDelegate error:error];
}
- (NSArray *)pathsWithPrefix:(NSString *)prefix delimiter:(NSString *)delimiter targetConnectionDelegate:(id<TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    PathReceiver *rec = [[[PathReceiver alloc] init] autorelease];
    S3Lister *lister = [[[S3Lister alloc] initWithS3AuthorizationProvider:sap endpoint:endpoint prefix:prefix delimiter:delimiter receiver:rec] autorelease];
    if (![lister listObjectsWithTargetConnectionDelegate:theDelegate error:error]) {
        return nil;
    }
    NSMutableArray *ret = [NSMutableArray arrayWithArray:[rec paths]];
    [ret addObjectsFromArray:[lister foundPrefixes]];
    [ret sortUsingSelector:@selector(compare:)];
    return ret;
}
- (NSArray *)commonPrefixesForPathPrefix:(NSString *)prefix delimiter:(NSString *)delimiter targetConnectionDelegate:(id<TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    NSArray *paths = [self pathsWithPrefix:prefix delimiter:delimiter targetConnectionDelegate:theDelegate error:error];
    if (paths == nil) {
        return nil;
    }
    NSMutableArray *ret = [NSMutableArray array];
    for (NSString *path in paths) {
        [ret addObject:[path substringFromIndex:[prefix length]]];
    }
    return ret;
}
- (NSArray *)objectsWithPrefix:(NSString *)prefix targetConnectionDelegate:(id<TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    S3ObjectReceiver *receiver = [[[S3ObjectReceiver alloc] init] autorelease];
    if (![self listObjectsWithPrefix:prefix receiver:receiver targetConnectionDelegate:theDelegate error:error]) {
        return NO;
    }
    return [receiver objects];
}
- (BOOL)listObjectsWithPrefix:(NSString *)prefix receiver:(id <S3Receiver>)receiver targetConnectionDelegate:(id<TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    S3Lister *lister = [[[S3Lister alloc] initWithS3AuthorizationProvider:sap endpoint:endpoint prefix:prefix delimiter:nil receiver:receiver] autorelease];
    return lister && [lister listObjectsWithTargetConnectionDelegate:theDelegate error:error];
}
- (NSNumber *)containsObjectAtPath:(NSString *)path dataSize:(unsigned long long *)dataSize targetConnectionDelegate:(id<TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    BOOL ret = YES;
    S3Request *s3r = [[S3Request alloc] initWithMethod:@"HEAD" endpoint:endpoint path:path queryString:nil authorizationProvider:sap error:error];
    if (s3r == nil) {
        return nil;
    }
    NSError *myError = nil;
    BOOL contains = NO;
    NSData *response = [s3r dataWithTargetConnectionDelegate:theDelegate error:&myError];
    if (response != nil) {
        contains = YES;
        HSLogTrace(@"S3 path %@ exists", path);
        if (dataSize != NULL) {
            NSString *contentLength = [s3r responseHeaderForKey:@"Content-Length"];
            *dataSize = (unsigned long long)[contentLength longLongValue]; // This would be bad for negative content-length (I guess that won't happen though)
        }
    } else if ([myError isErrorWithDomain:[S3Service errorDomain] code:ERROR_NOT_FOUND]) {
        contains = NO;
        HSLogDebug(@"S3 path %@ does NOT exist", path);
    } else if ([myError isErrorWithDomain:[S3Service errorDomain] code:ERROR_RRS_NOT_FOUND]) {
        contains = NO;
        HSLogDebug(@"S3 path %@ returns 405 error", path);
    } else {
        contains = NO;
        ret = NO;
        HSLogDebug(@"error getting HEAD for %@: %@", path, myError);
        SETERRORFROMMYERROR;
    }
    [s3r release];
    if (!ret) {
        return nil;
    }
    return [NSNumber numberWithBool:contains];
}
- (NSNumber *)isObjectRestoredAtPath:(NSString *)thePath targetConnectionDelegate:(id<TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    S3Request *s3r = [[[S3Request alloc] initWithMethod:@"HEAD" endpoint:endpoint path:thePath queryString:nil authorizationProvider:sap error:error] autorelease];
    if (s3r == nil) {
        return nil;
    }
    NSData *response = [s3r dataWithTargetConnectionDelegate:theDelegate error:error];
    if (response == nil) {
        return nil;
    }
    NSString *restoreHeader = [s3r responseHeaderForKey:@"x-amz-restore"];
    if (restoreHeader == nil) {
        // We're assuming here that the caller of this method has first requested a restore of this object.
        // If the object is new and hasn't been shifted to Glacier yet, the storage class of this object
        // would be Standard, the restore request would have failed, and there will be no x-amz-restore header.
        // There's no way to determine the object's current storage class from the results of a
        // HEAD request (unbelievably) so we have to make this assumption.
        
        return [NSNumber numberWithBool:YES];
    }
    HSLogDebug(@"S3 path %@: x-amz-restore=%@", thePath, restoreHeader);
    BOOL restored = [restoreHeader rangeOfString:@"ongoing-request=\"false\""].location != NSNotFound;
    return [NSNumber numberWithBool:restored];
}
- (BOOL)restoreObjectAtPath:(NSString *)thePath forDays:(NSUInteger)theDays alreadyRestoredOrRestoring:(BOOL *)alreadyRestoredOrRestoring targetConnectionDelegate:(id<TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    if (alreadyRestoredOrRestoring != NULL) {
        *alreadyRestoredOrRestoring = NO;
    }
    S3Request *s3r = [[[S3Request alloc] initWithMethod:@"POST" endpoint:endpoint path:thePath queryString:@"restore" authorizationProvider:sap error:error] autorelease];
    if (s3r == nil) {
        return NO;
    }
    NSString *requestBodyString = [NSString stringWithFormat:@"<RestoreRequest><Days>%ld</Days></RestoreRequest>", (unsigned long)theDays];
    NSData *requestBody = [requestBodyString dataUsingEncoding:NSUTF8StringEncoding];
    NSString *md5Hash = [MD5Hash hashDataBase64Encode:requestBody];
    [s3r setRequestHeader:md5Hash forKey:@"Content-MD5"];
    [s3r setRequestHeader:@"application/xml" forKey:@"Content-Type"];
    [s3r setRequestBody:requestBody];
    
    NSError *myError = nil;
    NSData *response = [s3r dataWithTargetConnectionDelegate:theDelegate error:&myError];
    if (response == nil) {
        if ([myError code] == S3SERVICE_ERROR_AMAZON_ERROR
            && [[[myError userInfo] objectForKey:@"HTTPStatusCode"] intValue] == HTTP_CONFLICT) {
            // AWS returns 409 conflict if it's already in the process of being restored.
            if (alreadyRestoredOrRestoring != NULL) {
                *alreadyRestoredOrRestoring = YES;
            }
            return YES;
        }
        if ([myError code] == S3SERVICE_ERROR_AMAZON_ERROR
            && [[[myError userInfo] objectForKey:@"HTTPStatusCode"] intValue] == HTTP_FORBIDDEN
            && [[[myError userInfo] objectForKey:@"AmazonCode"] isEqualToString:@"InvalidObjectState"]) {
            // AWS returns 403 and "InvalidObjectState" if the object's storage class isn't Glacier.
            // If the object is new and hasn't been shifted to Glacier yet, AWS will return this error,
            // which in our scenario isn't actually an error.
            if (alreadyRestoredOrRestoring != NULL) {
                *alreadyRestoredOrRestoring = YES;
            }
            return YES;
        }
        SETERRORFROMMYERROR;
        return NO;
    }
    
    // If the bucket does not have a restored copy of the object, Amazon S3 returns the following 202 Accepted response.
    // If a copy of the object is already restored, Amazon S3 returns a 200 OK response, only updating the restored copy's expiry time.
    if ([s3r httpResponseCode] == HTTP_OK) {
        if (alreadyRestoredOrRestoring != NULL) {
            *alreadyRestoredOrRestoring = YES;
        }
    }
    return YES;
}
- (NSData *)dataAtPath:(NSString *)path targetConnectionDelegate:(id<TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    return [self dataAtPath:path dataTransferDelegate:nil targetConnectionDelegate:theDelegate error:error];
}
- (NSData *)dataAtPath:(NSString *)path dataTransferDelegate:(id<DataTransferDelegate>)theDTD targetConnectionDelegate:(id<TargetConnectionDelegate>)theTCD error:(NSError **)error {
    S3Request *s3r = [[S3Request alloc] initWithMethod:@"GET" endpoint:endpoint path:path queryString:nil authorizationProvider:sap dataTransferDelegate:theDTD error:error];
    if (s3r == nil) {
        return nil;
    }
    NSData *ret = [s3r dataWithTargetConnectionDelegate:theTCD error:error];
    [s3r release];
    return ret;
}
- (S3AuthorizationProvider *)s3AuthorizationProvider {
    return sap;
}
- (BOOL)createS3Bucket:(NSString *)s3BucketName withLocationConstraint:(NSString *)theLocationConstraint targetConnectionDelegate:(id<TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    S3Request *s3r = [[[S3Request alloc] initWithMethod:@"PUT" endpoint:endpoint path:[NSString stringWithFormat:@"/%@/", s3BucketName] queryString:nil authorizationProvider:sap error:error] autorelease];
    if (s3r == nil) {
        return NO;
    }
    //    [s3r setHeader:@"bucket-owner-full-control" forKey:@"x-amz-acl"];
    
    if (theLocationConstraint != nil) {
        NSString *xml = [NSString stringWithFormat:@"<CreateBucketConfiguration xmlns=\"http://s3.amazonaws.com/doc/2006-03-01/\"><LocationConstraint>%@</LocationConstraint></CreateBucketConfiguration>", theLocationConstraint];
        NSData *data = [xml dataUsingEncoding:NSUTF8StringEncoding];
        [s3r setRequestBody:data];
    } else {
        [s3r setRequestBody:[NSData data]];
    }
    return [s3r dataWithTargetConnectionDelegate:theDelegate error:error] != nil;
}
- (BOOL)deleteS3Bucket:(NSString *)s3BucketName targetConnectionDelegate:(id<TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    S3Request *s3r = [[[S3Request alloc] initWithMethod:@"DELETE" endpoint:endpoint path:[NSString stringWithFormat:@"/%@/", s3BucketName] queryString:nil authorizationProvider:sap error:error] autorelease];
    if (s3r == nil) {
        return NO;
    }
    [s3r setRequestBody:[NSData data]]; // Do this so it sets Content-Length: 0 header.
    return [s3r dataWithTargetConnectionDelegate:theDelegate error:error] != nil;
}
- (BOOL)putData:(NSData *)data atPath:(NSString *)path targetConnectionDelegate:(id<TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    return [self putData:data atPath:path dataTransferDelegate:nil targetConnectionDelegate:theDelegate error:error];
}
- (BOOL)putData:(NSData *)data atPath:(NSString *)path dataTransferDelegate:(id<DataTransferDelegate>)theDTD targetConnectionDelegate:(id<TargetConnectionDelegate>)theTCD error:(NSError **)error {
    if (![path hasPrefix:@"/"]) {
        SETNSERROR([S3Service errorDomain], S3SERVICE_INVALID_PARAMETERS, @"path must begin with '/'");
        return NO;
	}
    HSLogDebug(@"putting %lu bytes in S3 at %@", (unsigned long)[data length], path);
    S3Request *s3r = [[S3Request alloc] initWithMethod:@"PUT" endpoint:endpoint path:path queryString:nil authorizationProvider:sap dataTransferDelegate:theDTD error:error];
    if (s3r == nil) {
        return NO;
    }
    [s3r setRequestBody:data];
    if (useAmazonRRS) {
        [s3r setRequestHeader:kS3StorageClassReducedRedundancy forKey:@"x-amz-storage-class"];
    }
    NSData *ret = [s3r dataWithTargetConnectionDelegate:theTCD error:error];
    [s3r release];
    if (ret == nil) {
        return NO;
    }
    return YES;
}
- (BOOL)deletePaths:(NSArray *)thePaths targetConnectionDelegate:(id<TargetConnectionDelegate>)theTCD error:(NSError **)error {
    if ([thePaths count] == 0) {
        HSLogWarn(@"0 paths to delete");
        return YES;
    }
    
    //    if ([AWSRegion regionWithS3Endpoint:endpoint] == nil) {
    //        HSLogDebug(@"not an AWS endpoint; not using multi-delete");
    
    
    // S3 Multi-delete doesn't seem to work! Using single delete:
    
    BOOL ret = YES;
    NSAutoreleasePool *pool = nil;
    for (NSString *path in thePaths) {
        [pool drain];
        pool = [[NSAutoreleasePool alloc] init];
        if (![self deletePath:path targetConnectionDelegate:theTCD error:error]) {
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

- (BOOL)deletePath:(NSString *)path targetConnectionDelegate:(id<TargetConnectionDelegate>)theTCD error:(NSError **)error {
	if (![path hasPrefix:@"/"]) {
        HSLogError(@"invalid path %@", path);
        SETNSERROR([S3Service errorDomain], S3SERVICE_INVALID_PARAMETERS, @"path must begin with /");
        return NO;
	}
	NSRange searchRange = NSMakeRange(1, [path length] - 1);
	NSRange nextSlashRange = [path rangeOfString:@"/" options:0 range:searchRange];
	if (nextSlashRange.location == NSNotFound) {
        SETNSERROR([S3Service errorDomain], S3SERVICE_INVALID_PARAMETERS, @"path must be of the format /<bucket name>/path");
        return NO;
	}
    
    HSLogDebug(@"deleting %@", path);
    S3Request *s3r = [[[S3Request alloc] initWithMethod:@"DELETE" endpoint:endpoint path:path queryString:nil authorizationProvider:sap error:error] autorelease];
    if (s3r == nil) {
        return NO;
    }
    NSData *response = [s3r dataWithTargetConnectionDelegate:theTCD error:error];
    if (response == nil) {
        return NO;
    }
    return YES;
}
- (BOOL)setStorageClass:(NSString *)storageClass forPath:(NSString *)path targetConnectionDelegate:(id<TargetConnectionDelegate>)theTCD error:(NSError **)error {
    if (![path hasPrefix:@"/"]) {
        SETNSERROR([S3Service errorDomain], S3SERVICE_INVALID_PARAMETERS, @"path must begin with '/'");
        return NO;
	}
    HSLogTrace(@"setting storage class to %@ for %@", storageClass, path);
    S3Request *s3r = [[S3Request alloc] initWithMethod:@"PUT" endpoint:endpoint path:path queryString:nil authorizationProvider:sap error:error];
    if (s3r == nil) {
        return NO;
    }
    [s3r setRequestHeader:storageClass forKey:@"x-amz-storage-class"];
    [s3r setRequestHeader:path forKey:@"x-amz-copy-source"];
    NSData *ret = [s3r dataWithTargetConnectionDelegate:theTCD error:error];
    [s3r release];
    if (ret == nil) {
        return NO;
    }
    return YES;
}
- (NSString *)storageClass {
    return useAmazonRRS ? kS3StorageClassReducedRedundancy : kS3StorageClassStandard;
}
- (BOOL)copy:(NSString *)sourcePath to:(NSString *)destPath targetConnectionDelegate:(id<TargetConnectionDelegate>)theTCD error:(NSError **)error {
    S3Request *s3r = [[[S3Request alloc] initWithMethod:@"PUT" endpoint:endpoint path:destPath queryString:nil authorizationProvider:sap error:error] autorelease];
    if (s3r == nil) {
        return NO;
    }
    [s3r setRequestHeader:sourcePath forKey:@"x-amz-copy-source"];
    NSData *response = [s3r dataWithTargetConnectionDelegate:theTCD error:error];
    if (response == nil) {
        return NO;
    }
    if ([response length] > 0) {
        HSLogTrace(@"s3 copy response: %@", [[[NSString alloc] initWithBytes:[response bytes] length:[response length] encoding:NSUTF8StringEncoding] autorelease]);
    }
    return YES;
}
- (NSNumber *)containsLifecyclePolicyWithId:(NSString *)theId forS3BucketName:(NSString *)theS3BucketName targetConnectionDelegate:(id<TargetConnectionDelegate>)theTCD error:(NSError **)error {
    NSString *path = [NSString stringWithFormat:@"/%@/", theS3BucketName];
    S3Request *s3r = [[S3Request alloc] initWithMethod:@"GET" endpoint:endpoint path:path queryString:@"lifecycle" authorizationProvider:sap error:error];
    if (s3r == nil) {
        return NO;
    }
    NSError *myError = nil;
    NSData *response = [s3r dataWithTargetConnectionDelegate:theTCD error:&myError];
    [s3r release];
    if (response == nil) {
        if ([myError isErrorWithDomain:[S3Service errorDomain] code:ERROR_NOT_FOUND]) {
            return [NSNumber numberWithBool:NO];
        }
        SETERRORFROMMYERROR;
        return nil;
    }
    LifecycleConfiguration *config = [[[LifecycleConfiguration alloc] initWithData:response error:error] autorelease];
    if (config == nil) {
        return nil;
    }
    BOOL contains = [config containsRuleWithId:theId];
    return [NSNumber numberWithBool:contains];
}
- (BOOL)putGlacierLifecyclePolicyWithId:(NSString *)theId forPrefixes:(NSArray *)thePrefixes s3BucketName:(NSString *)theS3BucketName transitionDays:(NSUInteger)theTransitionDays targetConnectionDelegate:(id<TargetConnectionDelegate>)theTCD error:(NSError **)error {
    NSString *path = [NSString stringWithFormat:@"/%@/", theS3BucketName];
    
    NSMutableString *configurationXML = [NSMutableString string];
    [configurationXML appendString:@"<LifecycleConfiguration>"];
    for (NSUInteger index = 0; index < [thePrefixes count]; index++) {
        NSString *ruleId = [NSString stringWithFormat:@"%@-%ld", theId, (unsigned long)index];
        [configurationXML appendString:@"<Rule>"];
        [configurationXML appendFormat:@"<ID>%@</ID>", ruleId];
        [configurationXML appendFormat:@"<Prefix>%@</Prefix>", [thePrefixes objectAtIndex:index]];
        [configurationXML appendString:@"<Status>Enabled</Status>"];
        [configurationXML appendFormat:@"<Transition><Days>%lu</Days><StorageClass>GLACIER</StorageClass></Transition>", (unsigned long)theTransitionDays];
        [configurationXML appendString:@"</Rule>"];
    }
    [configurationXML appendString:@"</LifecycleConfiguration>"];
    NSData *requestBody = [configurationXML dataUsingEncoding:NSUTF8StringEncoding];
    S3Request *s3r = [[S3Request alloc] initWithMethod:@"PUT" endpoint:endpoint path:path queryString:@"lifecycle" authorizationProvider:sap error:error];
    if (s3r == nil) {
        return NO;
    }
    NSString *md5Hash = [MD5Hash hashDataBase64Encode:requestBody];
    [s3r setRequestHeader:md5Hash forKey:@"Content-MD5"];
    [s3r setRequestBody:requestBody];
    NSData *ret = [s3r dataWithTargetConnectionDelegate:theTCD error:error];
    [s3r release];
    return ret != nil;
}


#pragma mark NSCopying
- (id)copyWithZone:(NSZone *)zone {
    return [[S3Service alloc] initWithS3AuthorizationProvider:sap endpoint:endpoint useAmazonRRS:useAmazonRRS];
}


#pragma mark internal
- (NSXMLDocument *)listBucketsWithTargetConnectionDelegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    S3Request *s3r = [[S3Request alloc] initWithMethod:@"GET" endpoint:endpoint path:@"/" queryString:nil authorizationProvider:sap error:error];
    if (s3r == nil) {
        return nil;
    }
    NSError *myError = nil;
    NSData *response = [s3r dataWithTargetConnectionDelegate:theDelegate error:&myError];
    [s3r release];
    if (response == nil) {
        SETERRORFROMMYERROR;
        if ([myError isErrorWithDomain:[S3Service errorDomain] code:S3SERVICE_ERROR_AMAZON_ERROR]) {
            NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithDictionary:[myError userInfo]];
            [userInfo setObject:[myError localizedDescription] forKey:NSLocalizedDescriptionKey];
            NSError *rewritten = [NSError errorWithDomain:[S3Service errorDomain] code:[[[myError userInfo] objectForKey:@"HTTPStatusCode"] intValue] userInfo:userInfo];
            if (error != NULL) {
                *error = rewritten;
            }
        }
        return nil;
    }
    NSXMLDocument *ret = [[[NSXMLDocument alloc] initWithData:response options:0 error:&myError] autorelease];
    if (ret == nil) {
        HSLogDebug(@"error parsing List Buckets result XML %@", [[[NSString alloc] initWithBytes:[response bytes] length:[response length] encoding:NSUTF8StringEncoding] autorelease]);
        SETNSERROR([S3Service errorDomain], [myError code], @"error parsing S3 List Buckets result XML: %@", [myError description]);
    }
    return ret;
}
- (BOOL)createOrDeleteS3Bucket:(NSString *)s3BucketName methodName:(NSString *)methodName requestBody:(NSData *)data targetConnectionDelegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    S3Request *s3r = [[[S3Request alloc] initWithMethod:methodName endpoint:endpoint path:[NSString stringWithFormat:@"/%@/", s3BucketName] queryString:nil authorizationProvider:sap error:error] autorelease];
    if (s3r == nil) {
        return NO;
    }
    if (data == nil) {
        [s3r setRequestBody:[NSData data]];
    } else {
        [s3r setRequestBody:data];
    }
    return [s3r dataWithTargetConnectionDelegate:theDelegate error:error] != nil;
}
@end
