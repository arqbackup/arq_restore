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


#import "Target.h"
#import "NSString_extra.h"
#import "AWSRegion.h"
#import "SFTPTargetConnection.h"
#import "GoogleDriveTargetConnection.h"
#import "S3TargetConnection.h"
#import "S3Service.h"
#import "S3AuthorizationProvider.h"
#import "TargetSchedule.h"
#import "DoubleIO.h"
#import "BooleanIO.h"
#import "IntegerIO.h"
#import "StringIO.h"


@implementation Target
- (id)initWithEndpoint:(NSURL *)theEndpoint secret:(NSString *)theSecret passphrase:(NSString *)thePassphrase {
    if (self = [super init]) {
        uuid = [[NSString stringWithRandomUUID] retain];
        endpoint = [theEndpoint retain];
        secret = [theSecret retain];
        targetType = [self targetTypeForEndpoint];
        passphrase = [thePassphrase retain];
    }
    return self;
}
- (id)initWithBufferedInputStream:(BufferedInputStream *)theBIS error:(NSError **)error {
    if (self = [super init]) {
        if (![StringIO read:&uuid from:theBIS error:error]) {
            [self release];
            return nil;
        }
        [uuid retain];
        NSString *theEndpointDescription = nil;
        if (![StringIO read:&theEndpointDescription from:theBIS error:error]) {
            [self release];
            return nil;
        }
        TargetSchedule *targetSchedule = [[TargetSchedule alloc] initWithBufferedInputStream:theBIS error:error];
        if (targetSchedule == nil) {
            [self release];
            return nil;
        }
        if (![BooleanIO read:&budgetEnabled from:theBIS error:error]
            || ![DoubleIO read:&budgetDollars from:theBIS error:error]
            || ![BooleanIO read:&useRRS from:theBIS error:error]
            || ![IntegerIO readUInt32:&budgetGB from:theBIS error:error]) {
            [self release];
            return nil;
        }
        
        endpoint = [[NSURL URLWithString:theEndpointDescription] copy];
        targetType = [self targetTypeForEndpoint];
        NSAssert(endpoint != nil, @"endpoint may not be nil");
    }
    return self;
}

- (void)dealloc {
    [uuid release];
    [endpoint release];
    [secret release];
    [passphrase release];
    [super dealloc];
}

- (NSString *)errorDomain {
    return @"TargetErrorDomain";
}
- (NSString *)targetUUID {
    return uuid;
}
- (NSURL *)endpoint {
    return endpoint;
}
- (NSString *)endpointDisplayName {
    TargetType theTargetType = [self targetType];
    switch (theTargetType) {
        case kTargetAWS:
            return @"Amazon";
        case kTargetGreenQloud:
            return @"GreenQloud";
        case kTargetDreamObjects:
            return @"DreamObjects";
        case kTargetGoogleCloudStorage:
            return @"Google Cloud Storage";
        case kTargetGoogleDrive:
            return @"Google Drive Storage";
    }
    return [endpoint host];
}
- (NSString *)secret:(NSError **)error {
    return secret;
}
- (NSString *)passphrase:(NSError **)error {
    if (passphrase == nil) {
        SETNSERROR([self errorDomain], ERROR_NOT_FOUND, @"passphrase not given");
        return nil;
    }
    return passphrase;
}
- (TargetType)targetType {
    return targetType;
}
- (id <TargetConnection>)newConnection {
    id <TargetConnection> ret = nil;
    if (targetType == kTargetSFTP) {
        ret = [[SFTPTargetConnection alloc] initWithTarget:self];
    } else if (targetType == kTargetGoogleDrive) {
        ret = [[GoogleDriveTargetConnection alloc] initWithTarget:self];
    } else {
        ret = [[S3TargetConnection alloc] initWithTarget:self];
    }
    return ret;
}
- (S3Service *)s3:(NSError **)error {
    if ([self targetType] == kTargetSFTP || [self targetType] == kTargetGoogleDrive) {
        SETNSERROR([self errorDomain], -1, @"cannot create S3Service for endpoint %@", endpoint);
        return nil;
    }
    
    S3AuthorizationProvider *sap = [[[S3AuthorizationProvider alloc] initWithAccessKey:[endpoint user] secretKey:secret] autorelease];
    NSString *portString = @"";
    if ([[endpoint port] intValue] != 0) {
        portString = [NSString stringWithFormat:@":%d", [[endpoint port] intValue]];
    }
    NSURL *s3Endpoint = [NSURL URLWithString:[NSString stringWithFormat:@"%@://%@%@", [endpoint scheme], [endpoint host], portString]];
    return [[[S3Service alloc] initWithS3AuthorizationProvider:sap endpoint:s3Endpoint useAmazonRRS:NO] autorelease];
}


#pragma mark NSObject
- (NSString *)description {
    return [NSString stringWithFormat:@"%@:%@", [endpoint host], [endpoint path]];
}


#pragma mark internal
- (TargetType)targetTypeForEndpoint {
    if ([[[self endpoint] scheme] isEqualToString:@"sftp"]) {
        return kTargetSFTP;
    }
    if ([[[self endpoint] scheme] isEqualToString:@"googledrive"]) {
        return kTargetGoogleDrive;
    }
    AWSRegion *awsRegion = [AWSRegion regionWithS3Endpoint:[self endpoint]];
    if (awsRegion != nil) {
        return kTargetAWS;
    }
    if ([[[self endpoint] host] isEqualToString:@"w.greenqloud.com"]) {
        return kTargetGreenQloud;
    }
    if ([[[self endpoint] host] isEqualToString:@"objects.dreamhost.com"]) {
        return kTargetDreamObjects;
    }
    if ([[[self endpoint] host] isEqualToString:@"storage.googleapis.com"]) {
        return kTargetGoogleCloudStorage;
    }
    return kTargetS3Compatible;
}
@end
