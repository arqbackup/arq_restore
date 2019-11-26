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



#import "Target.h"
#import "DictNode.h"
#import "StringIO.h"
#import "DoubleIO.h"
#import "BooleanIO.h"
#import "IntegerIO.h"
#import "AWSRegion.h"
#import "RemoteFS.h"
#import "RegexKitLite.h"
#import "S3AuthorizationProviderFactory.h"
#import "S3Service.h"
#import "AWSRegion.h"
#import "TargetConnection.h"
#import "IntegerNode.h"
#import "KeychainFactory.h"
#import "KeychainItem.h"
#import "Keychain.h"

static NSString *ARQ_RESTORE_TARGET_KEYCHAIN_LABEL = @"arq_restore target";
static NSString *ARQ_RESTORE_PASSPHRASE_KEYCHAIN_LABEL = @"arq_restore passphrase";
static NSString *ARQ_RESTORE_OAUTH2_CLIENT_SECRET_KEYCHAIN_LABEL = @"arq_restore oauth2 client secret";


@implementation Target
- (id)initWithUUID:(NSString *)theUUID
          nickname:(NSString *)theNickname
          endpoint:(NSURL *)theEndpoint
awsRequestSignatureVersion:(int32_t)theAWSRequestSignatureVersion {
    if (self = [super init]) {
        uuid = [theUUID retain];
        nickname = [theNickname retain];
        endpoint = [theEndpoint retain];
        awsRequestSignatureVersion = theAWSRequestSignatureVersion;
        targetType = [self targetTypeForEndpoint];
        NSAssert(endpoint != nil, @"endpoint may not be nil");
    }
    return self;
}
- (id)initWithPlist:(DictNode *)thePlist {
    if (self = [super init]) {
        uuid = [[[thePlist stringNodeForKey:@"uuid"] stringValue] copy];
        nickname = [[[thePlist stringNodeForKey:@"nickname"] stringValue] copy];
        endpoint = [[NSURL URLWithString:[[thePlist stringNodeForKey:@"endpointDescription"] stringValue]] copy];
        if ([[endpoint path] hasPrefix:@"//"] && [[endpoint path] length] > 2) {
            NSString *endpointDescription = [endpoint description];
            NSString *path = [endpoint path];
            NSString *prefix = [endpointDescription substringToIndex:[endpointDescription length] - [path length]];
            NSString *fixedPath = [[endpoint path] substringFromIndex:1];
            NSString *fixedEndpointDescription = [prefix stringByAppendingString:fixedPath];
            [endpoint release];
            endpoint = [[NSURL URLWithString:fixedEndpointDescription] copy];
        }
        if ([thePlist containsKey:@"awsRequestSignatureVersion"]) {
            awsRequestSignatureVersion = (int32_t)[[thePlist integerNodeForKey:@"awsRequestSignatureVersion"] intValue];
        } else {
            if ([AWSRegion regionWithS3Endpoint:endpoint] != nil) {
                awsRequestSignatureVersion = 4;
            } else {
                awsRequestSignatureVersion = 2;
            }
        }
        oAuth2ClientId = [[[thePlist stringNodeForKey:@"oAuth2ClientId"] stringValue] copy];
        oAuth2RedirectURI = [[[thePlist stringNodeForKey:@"oAuth2RedirectURI"] stringValue] copy];
        
        targetType = [self targetTypeForEndpoint];
        NSAssert(endpoint != nil, @"endpoint may not be nil");
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
        
        if (![StringIO read:&nickname from:theBIS error:error]) {
            [self release];
            return nil;
        }
        [nickname retain];

        NSString *theEndpointDescription = nil;
        if (![StringIO read:&theEndpointDescription from:theBIS error:error]) {
            [self release];
            return nil;
        }
        if (!![IntegerIO readInt32:&awsRequestSignatureVersion from:theBIS error:error]) {
            [self release];
            return nil;
        }

        if (![StringIO read:&oAuth2ClientId from:theBIS error:error]) {
            [self release];
            return nil;
        }
        [oAuth2ClientId retain];
        
        if (![StringIO read:&oAuth2RedirectURI from:theBIS error:error]) {
            [self release];
            return nil;
        }
        [oAuth2RedirectURI retain];
        
        endpoint = [[NSURL URLWithString:theEndpointDescription] copy];
        targetType = [self targetTypeForEndpoint];
        NSAssert(endpoint != nil, @"endpoint may not be nil");
    }
    return self;
}
- (void)dealloc {
    [uuid release];
    [nickname release];
    [endpoint release];
    [oAuth2ClientId release];
    [oAuth2RedirectURI release];
    [super dealloc];
}

- (NSString *)errorDomain {
    return @"TargetErrorDomain";
}

- (NSString *)targetUUID {
    return uuid;
}
- (NSString *)nickname {
    return nickname;
}
- (NSURL *)endpoint {
    return endpoint;
}
- (NSString *)endpointDisplayName {
    return nickname;
}
- (int)awsRequestSignatureVersion {
    return awsRequestSignatureVersion;
}

- (NSString *)secret:(NSError **)error {
    NSError *myError = nil;
    KeychainItem *item = [[KeychainFactory keychain] existingItemWithLabel:ARQ_RESTORE_TARGET_KEYCHAIN_LABEL account:uuid error:&myError];
    if (item == nil) {
        SETERRORFROMMYERROR;
        if ([myError code] == ERROR_NOT_FOUND) {
            SETNSERROR([self errorDomain], ERROR_MISSING_SECRET, @"Secret key not found in keychain for target %@ (%@)", uuid, endpoint);
        }
        return nil;
    }
    return [[[NSString alloc] initWithData:[item passwordData] encoding:NSUTF8StringEncoding] autorelease];
}
- (BOOL)setSecret:(NSString *)theSecret trustedAppPaths:(NSArray *)theTrustedAppPaths error:(NSError **)error {
    NSString *label = ARQ_RESTORE_TARGET_KEYCHAIN_LABEL;
    [[KeychainFactory keychain] destroyItemForLabel:label account:uuid error:NULL];
    KeychainItem *item = [[KeychainFactory keychain] createOrUpdateItemWithLabel:label account:uuid passwordData:[theSecret dataUsingEncoding:NSUTF8StringEncoding] trustedAppPaths:theTrustedAppPaths error:error];
    return item != nil;
}
- (BOOL)deleteSecret:(NSError **)error {
    return [[KeychainFactory keychain] destroyItemForLabel:ARQ_RESTORE_TARGET_KEYCHAIN_LABEL account:uuid error:error];
}

- (NSString *)passphrase:(NSError **)error {
    KeychainItem *item = [[KeychainFactory keychain] existingItemWithLabel:ARQ_RESTORE_PASSPHRASE_KEYCHAIN_LABEL account:uuid error:error];
    if (item == nil) {
        return nil;
    }
    return [[[NSString alloc] initWithData:[item passwordData] encoding:NSUTF8StringEncoding] autorelease];
}
- (BOOL)setPassphrase:(NSString *)theSecret trustedAppPaths:(NSArray *)theTrustedAppPaths error:(NSError **)error {
    NSString *label = ARQ_RESTORE_PASSPHRASE_KEYCHAIN_LABEL;
    [[KeychainFactory keychain] destroyItemForLabel:label account:uuid error:NULL];
    KeychainItem *item = [[KeychainFactory keychain] createOrUpdateItemWithLabel:label account:uuid passwordData:[theSecret dataUsingEncoding:NSUTF8StringEncoding] trustedAppPaths:theTrustedAppPaths error:error];
    return item != nil;
}
- (BOOL)deletePassphrase:(NSError **)error {
    return [[KeychainFactory keychain] destroyItemForLabel:ARQ_RESTORE_PASSPHRASE_KEYCHAIN_LABEL account:uuid error:error];
}

- (NSString *)oAuth2ClientId {
    return oAuth2ClientId;
}
- (void)setOAuth2ClientId:(NSString *)value {
    [value retain];
    [oAuth2ClientId release];
    oAuth2ClientId = value;
}

- (NSString *)oAuth2RedirectURI {
    return oAuth2RedirectURI;
}
- (void)setOAuth2RedirectURI:(NSString *)value {
    [value retain];
    [oAuth2RedirectURI release];
    oAuth2RedirectURI = value;
}

- (NSString *)oAuth2ClientSecret:(NSError **)error {
    NSError *myError = nil;
    KeychainItem *item = [[KeychainFactory keychain] existingItemWithLabel:ARQ_RESTORE_OAUTH2_CLIENT_SECRET_KEYCHAIN_LABEL account:uuid error:&myError];
    if (item == nil) {
        SETERRORFROMMYERROR;
        if ([myError code] == ERROR_NOT_FOUND) {
            SETNSERROR([self errorDomain], ERROR_MISSING_SECRET, @"Client secret not found in keychain for target %@ (%@)", uuid, endpoint);
        }
        return nil;
    }
    return [[[NSString alloc] initWithData:[item passwordData] encoding:NSUTF8StringEncoding] autorelease];
}
- (BOOL)setOAuth2ClientSecret:(NSString *)theSecret trustedAppPaths:(NSArray *)theTrustedAppPaths error:(NSError **)error {
    NSString *label = ARQ_RESTORE_OAUTH2_CLIENT_SECRET_KEYCHAIN_LABEL;
    [[KeychainFactory keychain] destroyItemForLabel:label account:uuid error:NULL];
    KeychainItem *item = [[KeychainFactory keychain] createOrUpdateItemWithLabel:label account:uuid passwordData:[theSecret dataUsingEncoding:NSUTF8StringEncoding] trustedAppPaths:theTrustedAppPaths error:error];
    return item != nil;
}
- (BOOL)deleteOAuth2ClientSecret:(NSError **)error {
    return [[KeychainFactory keychain] destroyItemForLabel:ARQ_RESTORE_OAUTH2_CLIENT_SECRET_KEYCHAIN_LABEL account:uuid error:error];
}


- (DictNode *)toPlist {
    DictNode *ret = [[[DictNode alloc] init] autorelease];
    [ret putString:@"s3" forKey:@"targetType"]; // Used by TargetFactory
    [ret putString:nickname forKey:@"nickname"];
    [ret putString:uuid forKey:@"uuid"];
    [ret putString:[endpoint absoluteString] forKey:@"endpointDescription"];
    [ret putInt:awsRequestSignatureVersion forKey:@"awsRequestSignatureVersion"];
    [ret putString:oAuth2ClientId forKey:@"oAuth2ClientId"];
    [ret putString:oAuth2RedirectURI forKey:@"oAuth2RedirectURI"];
    return ret;
}

- (BOOL)writeTo:(BufferedOutputStream *)theBOS error:(NSError **)error {
    return [StringIO write:uuid to:theBOS error:error]
    && [StringIO write:nickname to:theBOS error:error]
    && [StringIO write:[endpoint description] to:theBOS error:error]
    && [IntegerIO writeInt32:awsRequestSignatureVersion to:theBOS error:error]
    && [StringIO write:oAuth2ClientId to:theBOS error:error]
    && [StringIO write:oAuth2RedirectURI to:theBOS error:error];
}
- (void)writeTo:(NSMutableData *)data {
    [StringIO write:uuid to:data];
    [StringIO write:nickname to:data];
    [StringIO write:[endpoint description] to:data];
    [IntegerIO writeInt32:awsRequestSignatureVersion to:data];
    [StringIO write:oAuth2ClientId to:data];
    [StringIO write:oAuth2RedirectURI to:data];
}

- (S3Service *)s3:(NSError **)error {
    if ([self targetType] == kTargetLocal) {
        SETNSERROR([self errorDomain], -1, @"cannot create S3Service for endpoint %@", endpoint);
        return nil;
    }
    AWSRegion *awsRegion = [AWSRegion regionWithS3Endpoint:endpoint];
    if (awsRegion == nil) {
        // Default to us-east-1 for non-AWS endpoints.
        awsRegion = [AWSRegion usEast1];
    }
    NSString *secret = [self secret:error];
    if (secret == nil) {
        return nil;
    }
    
    id <S3AuthorizationProvider> sap = [[S3AuthorizationProviderFactory sharedS3AuthorizationProviderFactory] providerForEndpoint:endpoint
                                                                                                                        accessKey:[endpoint user]
                                                                                                                        secretKey:secret
                                                                                                                 signatureVersion:awsRequestSignatureVersion
                                                                                                                        awsRegion:awsRegion];
    NSString *portString = @"";
    if ([[endpoint port] intValue] != 0) {
        portString = [NSString stringWithFormat:@":%d", [[endpoint port] intValue]];
    }
    NSURL *s3Endpoint = [NSURL URLWithString:[NSString stringWithFormat:@"%@://%@%@", [endpoint scheme], [endpoint host], portString]];
    return [[[S3Service alloc] initWithS3AuthorizationProvider:sap endpoint:s3Endpoint] autorelease];
}

- (TargetConnection *)newConnection:(NSError **)error {
    return [[TargetConnection alloc] initWithTarget:self];
}
- (TargetType)targetType {
    return targetType;
}
- (BOOL)canAccessFilesByPath {
    return YES;
}


#pragma mark NSObject
- (BOOL)isEqual:(id)other {
    if (other == self) {
        return YES;
    }
    if (other == nil || ![other isKindOfClass:[self class]]) {
        return NO;
    }
    Target *target = (Target *)other;
    DictNode *myPlist = [self toPlist];
    DictNode *otherPlist = [target toPlist];
    return [myPlist isEqualToDictNode:otherPlist];
}
- (NSUInteger)hash {
    return [uuid hash];
}
- (NSString *)description {
    return [NSString stringWithFormat:@"%@:%@", [endpoint host], [endpoint path]];
}


#pragma mark internal
- (TargetType)targetTypeForEndpoint {
    if ([[[self endpoint] scheme] isEqualToString:@"file"]) {
        return kTargetLocal;
    }
    
    return kTargetAWS;
}
@end
