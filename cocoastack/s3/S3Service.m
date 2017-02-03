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
#import "SHA256Hash.h"
#import "NSString_extra.h"
#import "ISO8601Date.h"
#import "Item.h"
#import "S3ObjectsLister.h"


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

- (id)initWithS3AuthorizationProvider:(id <S3AuthorizationProvider>)theSAP endpoint:(NSURL *)theEndpoint {
	if (self = [super init]) {
		sap = [theSAP retain];
        endpoint = [theEndpoint retain];
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
    NSDate *now = [NSDate date];
    NSString *contentSHA256 = [NSString hexStringWithData:[SHA256Hash hashData:[@"" dataUsingEncoding:NSUTF8StringEncoding]]];
    if ([sap signatureVersion] == 4) {
        [conn setRequestHeader:[[ISO8601Date sharedISO8601Date] basicDateTimeStringFromDate:now] forKey:@"x-amz-date"];
        [conn setRequestHeader:contentSHA256 forKey:@"x-amz-content-sha256"];
    } else {
        [conn setRFC822DateRequestHeader];
    }
    NSString *stringToSign = nil;
    NSString *canonicalRequest = nil;
    if (![sap setAuthorizationOnHTTPConnection:conn contentSHA256:contentSHA256 now:now stringToSign:&stringToSign canonicalRequest:&canonicalRequest error:error]) {
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
        S3ErrorResult *errorResult = [[[S3ErrorResult alloc] initWithAction:[NSString stringWithFormat:@"GET %@", url] data:response httpErrorCode:(int)code stringToSign:stringToSign canonicalRequest:canonicalRequest] autorelease];
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
        HSLogDebug(@"list Objects XML data: %@", [[[NSString alloc] initWithData:response encoding:NSUTF8StringEncoding] autorelease]);
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


#pragma mark ItemFS
- (NSString *)itemFSDescription {
    return [NSString stringWithFormat:@"s3:%@", [endpoint description]];
}
- (BOOL)canRemoveDirectoriesAtomically {
    return NO;
}
- (BOOL)usesFolderIds {
    return NO;
}
- (BOOL)enforcesUniqueFilenames {
    return YES;
}
- (Item *)rootDirectoryItemWithTargetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD error:(NSError **)error {
    Item *item = [[[Item alloc] init] autorelease];
    item.name = @"/";
    item.isDirectory = YES;
    return item;
}
- (NSDictionary *)itemsByNameInDirectoryItem:(Item *)theItem path:(NSString *)theDirectoryPath targetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD duplicatesWereMerged:(BOOL *)duplicatesWereMerged error:(NSError **)error {
    *duplicatesWereMerged = NO;
    
    if ([theDirectoryPath isEqualToString:@"/"]) {
        NSArray *bucketNames = [self s3BucketNamesWithTargetConnectionDelegate:theTCD error:error];
        if (bucketNames == nil) {
            return nil;
        }
        NSMutableDictionary *ret = [NSMutableDictionary dictionary];
        for (NSString *name in bucketNames) {
            Item *item = [[[Item alloc] init] autorelease];
            item.name = name;
            item.isDirectory = YES;
            [ret setObject:item forKey:name];
        }
        return ret;
    }
    if (![theDirectoryPath hasSuffix:@"/"]) {
        theDirectoryPath = [theDirectoryPath stringByAppendingString:@"/"];
    }
    
    NSDictionary *ret = nil;
    if ([theDirectoryPath isMatchedByRegex:@"^/([^/]+)/(\\S{8}-\\S{4}-\\S{4}-\\S{4}-\\S{12})/objects/$"]) {
        S3ObjectsLister *lister = [[[S3ObjectsLister alloc] initWithS3AuthorizationProvider:sap
                                                                           endpoint:endpoint
                                                                               path:theDirectoryPath
                                                           targetConnectionDelegate:theTCD] autorelease];
        ret = [lister itemsByName:error];
    } else {
        S3Lister *lister = [[[S3Lister alloc] initWithS3AuthorizationProvider:sap
                                                                     endpoint:endpoint
                                                                         path:theDirectoryPath
                                                                    delimiter:@"/"
                                                     targetConnectionDelegate:theTCD] autorelease];
        ret = [lister itemsByName:error];
    }
    return ret;
}
- (Item *)createDirectoryWithName:(NSString *)theName inDirectoryItem:(Item *)theDirectoryItem itemPath:(NSString *)thePath targetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD error:(NSError **)error {
    // There's no such thing as a directory in S3.
    Item *item = [[[Item alloc] init] autorelease];
    item.name = theName;
    item.isDirectory = YES;
    return item;
}
- (BOOL)removeDirectoryItem:(Item *)theItem inDirectoryItem:(Item *)theParentDirectoryItem itemPath:(NSString *)thePath targetConnectionDelegate:(id<TargetConnectionDelegate>)theTCD error:(NSError **)error {
    // There's no such thing as a directory in S3.
    return YES;
}
- (NSData *)contentsOfRange:(NSRange)theRange ofFileItem:(Item *)theItem itemPath:(NSString *)theFullPath dataTransferDelegate:(id <DataTransferDelegate>)theDTD targetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD error:(NSError **)error {
    S3Request *s3r = [[S3Request alloc] initWithMethod:@"GET" endpoint:endpoint path:theFullPath queryString:nil authorizationProvider:sap dataTransferDelegate:theDTD error:error];
    if (s3r == nil) {
        return nil;
    }
    if (theRange.location != NSNotFound) {
        [s3r setRequestHeader:[NSString stringWithFormat:@"bytes=%ld-%ld", theRange.location, (theRange.location + theRange.length - 1)] forKey:@"Range"];
    }
    NSData *ret = [s3r dataWithTargetConnectionDelegate:theTCD error:error];
    [s3r release];
    
    if (theRange.location != NSNotFound && [ret length] != theRange.length) {
        SETNSERROR([S3Service errorDomain], -1, @"requested bytes at %ld length %ld but got %ld bytes", theRange.location, theRange.length, [ret length]);
        return nil;
    }
    return ret;
}
- (Item *)createFileWithData:(NSData *)theData name:(NSString *)theName inDirectoryItem:(Item *)theDirectoryItem existingItem:(Item *)theExistingItem itemPath:(NSString *)theFullPath dataTransferDelegate:(id <DataTransferDelegate>)theDTD targetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD error:(NSError **)error {
    if (![theFullPath hasPrefix:@"/"]) {
        SETNSERROR([S3Service errorDomain], S3SERVICE_INVALID_PARAMETERS, @"path must begin with '/'");
        return nil;
    }
    S3Request *s3r = [[[S3Request alloc] initWithMethod:@"PUT" endpoint:endpoint path:theFullPath queryString:nil authorizationProvider:sap dataTransferDelegate:theDTD error:error] autorelease];
    if (s3r == nil) {
        return nil;
    }
    
    [s3r setRequestBody:theData];
    NSTimeInterval start = [NSDate timeIntervalSinceReferenceDate];
    NSData *ret = [s3r dataWithTargetConnectionDelegate:theTCD error:error];
    NSString *etag = [[[s3r responseHeaderForKey:@"ETag"] retain] autorelease];
    if (etag == nil) {
        // Sometimes S3 doesn't capitalize the T in ETag, even though their doc says "ETag".
        etag = [s3r responseHeaderForKey:@"Etag"];
    }
    if (ret == nil) {
        return nil;
    }
    NSTimeInterval end = [NSDate timeIntervalSinceReferenceDate];
    NSTimeInterval duration = end - start;
    if (duration != 0) {
        HSLogDebug(@"uploaded %ld bytes to %@ in %0.1f seconds (%01.f bytes/sec)", (unsigned long)[theData length], theFullPath, duration, ([theData length] / duration));
    }
    
    Item *item = [[[Item alloc] init] autorelease];
    item.name = theName;
    item.isDirectory = NO;
    item.fileSize = [theData length];
    item.fileLastModified = [NSDate date];
    
    if (etag != nil) {
        if ([etag hasPrefix:@"\""] && [etag hasSuffix:@"\""]) {
            etag = [etag substringWithRange:NSMakeRange(1, [etag length] - 2)];
        }
        item.checksum = [@"md5:" stringByAppendingString:etag];
    }
    if (item.checksum == nil) {
        HSLogDebug(@"no checksum found in S3 response for %@: response headers=%@", theFullPath, [s3r responseHeaderKeys]);
    }

    return item;
}
- (BOOL)moveItem:(Item *)theItem toNewName:(NSString *)theNewName fromDirectoryItem:(Item *)theFromDirectoryItem fromDirectory:(NSString *)theFromDir toDirectoryItem:(Item *)theToDirectoryItem toDirectory:(NSString *)theToDir targetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD error:(NSError **)error {
    SETNSERROR([S3Service errorDomain], -1, @"S3Service moveItem not implemented");
    return NO;
}
- (BOOL)removeFileItem:(Item *)theItem itemPath:(NSString *)theFullPath targetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD error:(NSError **)error {
    NSRange searchRange = NSMakeRange(1, [theFullPath length] - 1);
    NSRange nextSlashRange = [theFullPath rangeOfString:@"/" options:0 range:searchRange];
    if (nextSlashRange.location == NSNotFound) {
        SETNSERROR([S3Service errorDomain], S3SERVICE_INVALID_PARAMETERS, @"path must be of the format /<bucket name>/path");
        return NO;
    }
    
    HSLogDebug(@"deleting %@", theFullPath);
    S3Request *s3r = [[[S3Request alloc] initWithMethod:@"DELETE" endpoint:endpoint path:theFullPath queryString:nil authorizationProvider:sap error:error] autorelease];
    if (s3r == nil) {
        return NO;
    }
    NSData *response = [s3r dataWithTargetConnectionDelegate:theTCD error:error];
    if (response == nil) {
        return NO;
    }
    return YES;
}
- (NSNumber *)freeBytesAtPath:(NSString *)thePath targetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD error:(NSError **)error {
    return [NSNumber numberWithUnsignedLongLong:LLONG_MAX];
}
- (BOOL)updateFingerprintWithTargetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD error:(NSError **)error {
    SETNSERROR([S3Service errorDomain], -1, @"S3Service updateFingerprintWithTargetConnectionDelegate not implemented");
    return NO;
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
- (BOOL)restoreObjectAtPath:(NSString *)thePath forDays:(NSUInteger)theDays tier:(int)theGlacierRetrievalTier alreadyRestoredOrRestoring:(BOOL *)alreadyRestoredOrRestoring targetConnectionDelegate:(id<TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    if (alreadyRestoredOrRestoring != NULL) {
        *alreadyRestoredOrRestoring = NO;
    }
    S3Request *s3r = [[[S3Request alloc] initWithMethod:@"POST" endpoint:endpoint path:thePath queryString:@"restore" authorizationProvider:sap error:error] autorelease];
    if (s3r == nil) {
        return NO;
    }
    NSString *glacierRetrievalTierText = @"Standard";
    switch (theGlacierRetrievalTier) {
        case GLACIER_RETRIEVAL_TIER_BULK:
            glacierRetrievalTierText = @"Bulk";
        case GLACIER_RETRIEVAL_TIER_STANDARD:
            glacierRetrievalTierText = @"Standard";
            break;
        case GLACIER_RETRIEVAL_TIER_EXPEDITED:
            glacierRetrievalTierText = @"Expedited";
            break;
    }
    NSString *requestBodyString = [NSString stringWithFormat:@"<RestoreRequest><Days>%ld</Days><GlacierJobParameters><Tier>%@</Tier></GlacierJobParameters></RestoreRequest>", (unsigned long)theDays, glacierRetrievalTierText];
    NSData *requestBody = [requestBodyString dataUsingEncoding:NSUTF8StringEncoding];
    NSString *md5Hash = [MD5Hash hashDataBase64Encode:requestBody];
    [s3r setRequestHeader:md5Hash forKey:@"Content-MD5"];
    [s3r setRequestHeader:@"application/xml" forKey:@"Content-Type"];
    [s3r setRequestBody:requestBody];
    
    HSLogDebug(@"requesting restore of %@ (tier=%@)", thePath, glacierRetrievalTierText);
    
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
- (BOOL)removeItemById:(NSString *)theItemId targetConnectionDelegate:(id<TargetConnectionDelegate>)theTCD error:(NSError **)error {
    SETNSERROR([S3Service errorDomain], -1, @"removeItemById not implemented");
    return NO;
}


#pragma mark NSCopying
- (id)copyWithZone:(NSZone *)zone {
    return [[S3Service alloc] initWithS3AuthorizationProvider:sap endpoint:endpoint];
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
- (BOOL)removeDirectory:(NSString *)thePath targetConnectionDelegate:(id<TargetConnectionDelegate>)theTCD error:(NSError **)error {
    BOOL duplicatesWereMerged = NO;
    NSDictionary *itemsByName = [self itemsByNameInDirectoryItem:nil path:thePath targetConnectionDelegate:theTCD duplicatesWereMerged:&duplicatesWereMerged error:error];
    if (itemsByName == nil) {
        return NO;
    }
    for (Item *item in [itemsByName allValues]) {
        NSString *childPath = [thePath stringByAppendingPathComponent:item.name];
        if (item.isDirectory) {
            if (![self removeDirectory:childPath targetConnectionDelegate:theTCD error:error]) {
                return NO;
            }
        } else {
            if (![self removeFileItem:nil itemPath:childPath targetConnectionDelegate:theTCD error:error]) {
                return NO;
            }
        }
    }
    return YES;
}
@end
