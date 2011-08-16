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
#import "InputStream.h"
#import "Blob.h"
#import "RegexKitLite.h"
#import "NSError_S3.h"
#import "S3Lister.h"
#import "S3AuthorizationProvider.h"
#import "S3Service.h"
#import "PathReceiver.h"
#import "SetNSError.h"
#import "DataInputStream.h"
#import "HTTP.h"
#import "Streams.h"
#import "S3ObjectReceiver.h"
#import "ServerBlob.h"
#import "NSErrorCodes.h"
#import "NSData-InputStream.h"
#import "S3Request.h"
#import "NSError_extra.h"


/*
 * WARNING:
 * This class *must* be reentrant!
 */

@interface S3Service (internal)
- (NSXMLDocument *)listBuckets:(NSError **)error;
- (BOOL)internalACL:(int *)acl atPath:(NSString *)path error:(NSError **)error;
@end

@implementation S3Service
+ (NSString *)errorDomain {
    return @"S3ServiceErrorDomain";
}
+ (NSString *)displayNameForBucketRegion:(int)region {
    switch (region) {
        case BUCKET_REGION_US_STANDARD:
            return @"US Standard";
        case BUCKET_REGION_US_WEST:
            return @"US-West (Northern California)";
        case BUCKET_REGION_AP_SOUTHEAST_1:
            return @"Asia Pacific (Singapore)";
        case BUCKET_REGION_AP_NORTHEAST_1:
            return @"Asia Pacific (Japan)";
        case BUCKET_REGION_EU:
            return @"EU (Ireland)";
    }
    NSAssert(NO, @"invalid S3 bucket region");
    return nil;
}
+ (NSString *)s3BucketNameForAccessKeyID:(NSString *)theAccessKeyID region:(int)s3BucketRegion {
    NSString *regionSuffix = @"";
    if (s3BucketRegion == BUCKET_REGION_US_WEST) {
        regionSuffix = @".us-west-1";
    } else if (s3BucketRegion == BUCKET_REGION_AP_SOUTHEAST_1) {
        regionSuffix = @".ap-southeast-1";
    } else if (s3BucketRegion == BUCKET_REGION_AP_NORTHEAST_1) {
        regionSuffix = @".ap-northeast-1";
    } else if (s3BucketRegion == BUCKET_REGION_AP_NORTHEAST_1) {
        regionSuffix = @".ap-northeast-1";
    } else if (s3BucketRegion == BUCKET_REGION_EU) {
        regionSuffix = @".eu";
    }
    return [NSString stringWithFormat:@"%@.com.haystacksoftware.arq%@", [theAccessKeyID lowercaseString], regionSuffix];
}
+ (int)s3BucketRegionForS3BucketName:(NSString *)s3BucketName {
	if ([s3BucketName hasSuffix:@"com.haystacksoftware.arq.eu"]) {
		return BUCKET_REGION_EU;
	} else if ([s3BucketName hasSuffix:@"com.haystacksoftware.arq.ap-southeast-1"]) {
		return BUCKET_REGION_AP_SOUTHEAST_1;
	} else if ([s3BucketName hasSuffix:@"com.haystacksoftware.arq.ap-northeast-1"]) {
		return BUCKET_REGION_AP_NORTHEAST_1;
	} else if ([s3BucketName hasSuffix:@"com.haystacksoftware.arq.us-west-1"]) {
		return BUCKET_REGION_US_WEST;
	}
	return BUCKET_REGION_US_STANDARD;
}
+ (NSArray *)s3BucketNamesForAccessKeyID:(NSString *)theAccessKeyId {
	return [NSArray arrayWithObjects:
			[S3Service s3BucketNameForAccessKeyID:theAccessKeyId region:BUCKET_REGION_US_STANDARD],
			[S3Service s3BucketNameForAccessKeyID:theAccessKeyId region:BUCKET_REGION_US_WEST],
			[S3Service s3BucketNameForAccessKeyID:theAccessKeyId region:BUCKET_REGION_EU],
			[S3Service s3BucketNameForAccessKeyID:theAccessKeyId region:BUCKET_REGION_AP_SOUTHEAST_1],
			[S3Service s3BucketNameForAccessKeyID:theAccessKeyId region:BUCKET_REGION_AP_NORTHEAST_1],
			nil];
}
- (id)initWithS3AuthorizationProvider:(S3AuthorizationProvider *)theSAP useSSL:(BOOL)isUseSSL retryOnTransientError:(BOOL)retry {
	if (self = [super init]) {
		sap = [theSAP retain];
        useSSL = isUseSSL;
        retryOnTransientError = retry;
    }
    return self;
}
- (void)dealloc {
	[sap release];
	[super dealloc];
}
- (NSArray *)s3BucketNames:(NSError **)error {
	NSXMLDocument *doc = [self listBuckets:error];
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
- (BOOL)s3BucketExists:(NSString *)s3BucketName {
    NSError *error = nil;
    NSArray *s3BucketNames = [self s3BucketNames:&error];
    if (!s3BucketNames) {
        HSLogDebug(@"error getting S3 bucket names: %@", [error localizedDescription]);
        return NO;
    }
    return [s3BucketNames containsObject:s3BucketName];
}
- (NSArray *)pathsWithPrefix:(NSString *)prefix error:(NSError **)error {
    return [self pathsWithPrefix:prefix delimiter:nil error:error];
}
- (NSArray *)pathsWithPrefix:(NSString *)prefix delimiter:(NSString *)delimiter error:(NSError **)error {
    PathReceiver *rec = [[[PathReceiver alloc] init] autorelease];
    S3Lister *lister = [[[S3Lister alloc] initWithS3AuthorizationProvider:sap useSSL:useSSL retryOnTransientError:retryOnTransientError prefix:prefix delimiter:delimiter receiver:rec] autorelease];
    if (![lister listObjects:error]) {
        return nil;
    }
    NSMutableArray *ret = [NSMutableArray arrayWithArray:[rec paths]];
    [ret addObjectsFromArray:[lister foundPrefixes]];
    [ret sortUsingSelector:@selector(compare:)];
    return ret;
}
- (NSArray *)commonPrefixesForPathPrefix:(NSString *)prefix delimiter:(NSString *)delimiter error:(NSError **)error {
    NSArray *paths = [self pathsWithPrefix:prefix delimiter:delimiter error:error];
    if (paths == nil) {
        return nil;
    }
    NSMutableArray *ret = [NSMutableArray array];
    for (NSString *path in paths) {
        [ret addObject:[path lastPathComponent]];
    }
    return ret;
}
- (NSArray *)objectsWithPrefix:(NSString *)prefix error:(NSError **)error {
    S3ObjectReceiver *receiver = [[[S3ObjectReceiver alloc] init] autorelease];
    if (![self listObjectsWithPrefix:prefix receiver:receiver error:error]) {
        return NO;
    }
    return [receiver objects];
}
- (BOOL)listObjectsWithPrefix:(NSString *)prefix receiver:(id <S3Receiver>)receiver error:(NSError **)error {
    S3Lister *lister = [[[S3Lister alloc] initWithS3AuthorizationProvider:sap useSSL:useSSL retryOnTransientError:retryOnTransientError prefix:prefix delimiter:nil receiver:receiver] autorelease];
    return lister && [lister listObjects:error];
}
- (BOOL)containsBlob:(BOOL *)contains atPath:(NSString *)path dataSize:(unsigned long long *)dataSize error:(NSError **)error {
    BOOL ret = YES;
    S3Request *s3r = [[S3Request alloc] initWithMethod:@"HEAD" path:path queryString:nil authorizationProvider:sap useSSL:useSSL retryOnTransientError:retryOnTransientError];
    NSError *myError = nil;
    ServerBlob *sb = [s3r newServerBlob:&myError];
    if (sb != nil) {
        *contains = YES;
        HSLogTrace(@"S3 path %@ exists", path);
    } else if ([myError isErrorWithDomain:[S3Service errorDomain] code:ERROR_NOT_FOUND]) {
        *contains = NO;
        HSLogDebug(@"S3 path %@ does NOT exist", path);
    } else {
        *contains = NO;
        ret = NO;
        HSLogDebug(@"error getting HEAD for %@: %@", path, myError);
        if (error != NULL) { *error = myError; }
    }
    [sb release];
    [s3r release];
    return ret;
}
- (NSData *)dataAtPath:(NSString *)path error:(NSError **)error {
    ServerBlob *sb = [self newServerBlobAtPath:path error:error];
    if (sb == nil) {
        return nil;
    }
    NSData *data = [sb slurp:error];
    [sb release];
    return data;
}
- (ServerBlob *)newServerBlobAtPath:(NSString *)path error:(NSError **)error {
    HSLogDebug(@"getting %@", path);
    S3Request *s3r = [[S3Request alloc] initWithMethod:@"GET" path:path queryString:nil authorizationProvider:sap useSSL:useSSL retryOnTransientError:retryOnTransientError];
    ServerBlob *sb = [s3r newServerBlob:error];
    [s3r release];
    return sb;
}
- (BOOL)aclXMLData:(NSData **)aclXMLData atPath:(NSString *)path error:(NSError **)error {
    *aclXMLData = nil;
    HSLogDebug(@"getting %@", path);
    S3Request *s3r = [[S3Request alloc] initWithMethod:@"GET" path:path queryString:@"?acl" authorizationProvider:sap useSSL:useSSL retryOnTransientError:retryOnTransientError];
    ServerBlob *sb = [s3r newServerBlob:error];
    [s3r release];
    if (sb == nil) {
        return NO;
    }
    NSData *output = [sb slurp:error];
    [sb release];
    if (output == nil) {
        return NO;
    }
    *aclXMLData = output;
    return YES;
}
- (BOOL)acl:(int *)acl atPath:(NSString *)path error:(NSError **)error {
	if (error != NULL) {
		*error = nil;
	}
    *acl = 0;
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    BOOL ret = [self internalACL:acl atPath:path error:error];
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

@implementation S3Service (internal)
- (NSXMLDocument *)listBuckets:(NSError **)error {
    S3Request *s3r = [[S3Request alloc] initWithMethod:@"GET" path:@"/" queryString:nil authorizationProvider:sap useSSL:useSSL retryOnTransientError:retryOnTransientError];
    ServerBlob *sb = [s3r newServerBlob:error];
    [s3r release];
    if (sb == nil) {
        return nil;
    }
    NSData *data = [sb slurp:error];
    [sb release];
    if (data == nil) {
        return nil;
    }
    return [[[NSXMLDocument alloc] initWithData:data options:0 error:error] autorelease];
}
- (BOOL)internalACL:(int *)acl atPath:(NSString *)path error:(NSError **)error {
    NSData *aclData;
    if (![self aclXMLData:&aclData atPath:path error:error]) {
        return NO;
    }
	NSXMLDocument *xmlDoc = [[[NSXMLDocument alloc] initWithData:aclData options:0 error:error] autorelease];
    if (!xmlDoc) {
        return NO;
    }
    NSArray *grants = [xmlDoc nodesForXPath:@"AccessControlPolicy/AccessControlList/Grant" error:error];
    if (!grants) {
        return NO;
    }
    BOOL publicRead = NO;
    BOOL publicWrite = NO;
    for (NSXMLElement *grant in grants) {
        NSArray *grantees = [grant nodesForXPath:@"Grantee" error:error];
        if (!grantees) {
            return NO;
        }
        for (NSXMLElement *grantee in grantees) {
            NSString *xsiType = [[grantee attributeForName:@"xsi:type"] stringValue];
            if ([xsiType isEqualToString:@"Group"]) {
                NSArray *uris = [grantee nodesForXPath:@"URI" error:error];
                if (!uris) {
                    return NO;
                }
                if ([uris count] > 0) {
                    if ([[[uris objectAtIndex:0] stringValue] isEqualToString:@"http://acs.amazonaws.com/groups/global/AllUsers"]) {
                        NSArray *permissions = [grant nodesForXPath:@"Permission" error:error];
                        if (!permissions) {
                            return NO;
                        }
                        for (NSXMLElement *permission in permissions) {
                            if ([[permission stringValue] isEqualToString:@"WRITE"]) {
                                publicWrite = YES;
                            } else if ([[permission stringValue] isEqualToString:@"READ"]) {
                                publicRead = YES;
                            } else {
                                SETNSERROR([S3Service errorDomain], S3SERVICE_ERROR_UNEXPECTED_RESPONSE, @"unexpected permission");
                                return NO;
                            }
                        }
                    }
                }
            }
        }
    }
    if (publicRead && publicWrite) {
        *acl = PUBLIC_READ_WRITE;
    } else if (publicRead) {
        *acl = PUBLIC_READ;
    } else {
        *acl = PRIVATE;
    }
    return YES;
}
@end
