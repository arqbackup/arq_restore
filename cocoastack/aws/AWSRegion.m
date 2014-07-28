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

#import "AWSRegion.h"
#import "RegexKitLite.h"



@implementation AWSRegion
+ (NSArray *)allRegions {
    return [NSArray arrayWithObjects:
            [AWSRegion usEast1],
            [AWSRegion usWest1],
            [AWSRegion usWest2],
            [AWSRegion euWest1],
            [AWSRegion apSoutheast1],
            [AWSRegion apSoutheast2],
            [AWSRegion apNortheast1],
            [AWSRegion saEast1],
            nil];
}
+ (NSArray *)s3Regions {
    return [AWSRegion allRegions];
}
+ (NSArray *)glacierRegions {
    NSMutableArray *ret = [NSMutableArray array];
    for (AWSRegion *region in [AWSRegion allRegions]) {
        if ([region supportsGlacier]) {
            [ret addObject:region];
        }
    }
    return ret;
}
+ (AWSRegion *)regionWithName:(NSString *)theRegionName {
    for (AWSRegion *region in [AWSRegion allRegions]) {
        if ([[region regionName] isEqualToString:theRegionName]) {
            return region;
        }
    }
    return nil;
}
+ (AWSRegion *)regionWithLocation:(NSString *)theLocation {
    if ([theLocation length] == 0) {
        return [AWSRegion usEast1];
    }
    
    for (AWSRegion *region in [AWSRegion allRegions]) {
        for (NSString *constraint in [region s3LocationConstraints]) {
            if ([constraint caseInsensitiveCompare:theLocation] == NSOrderedSame) {
                return region;
            }
        }
    }
    HSLogDebug(@"no AWS region found for location %@", theLocation);
    return nil;
}
+ (AWSRegion *)regionWithS3Endpoint:(NSURL *)theEndpoint {
    if (![[theEndpoint scheme] isEqualToString:@"https"] && ![[theEndpoint scheme] isEqualToString:@"http"]) {
//        HSLogDebug(@"unknown AWSRegion endpoint scheme: %@", theEndpoint);
        return nil;
    }
    
    for (AWSRegion *region in [AWSRegion allRegions]) {
        NSURL *endpoint = [region s3EndpointWithSSL:YES];
        if ([[theEndpoint host] isEqualToString:[endpoint host]]) {
            return region;
        }
    }
//    HSLogDebug(@"AWSRegion not found for S3 endpoint %@", theEndpoint);
    return nil;
}
+ (AWSRegion *)usEast1 {
    return [[[AWSRegion alloc] initWithRegionName:@"us-east-1"
                            s3LocationConstraints:nil
                                       s3Hostname:@"s3.amazonaws.com"
                                      displayName:@"US East (Northern Virginia)"
                                 shortDisplayName:@"N. Virginia"
               s3StorageDollarsPerGBMonthStandard:.030
                    s3StorageDollarsPerGBMonthRRS:.024
                             s3UploadDollarsPerGB:.005
                    s3DataTransferOutDollarsPerGB:.12
                  glacierStorageDollarsPerGBMonth:.01
                        glacierUploadDollarsPerGB:.05
               glacierDataTransferOutDollarsPerGB:.12
                                  supportsGlacier:YES] autorelease];
}
+ (AWSRegion *)usWest1 {
    return [[[AWSRegion alloc] initWithRegionName:@"us-west-1"
                            s3LocationConstraints:[NSArray arrayWithObject:@"us-west-1"]
                                       s3Hostname:@"s3-us-west-1.amazonaws.com"
                                      displayName:@"US West (Northern California)"
                                 shortDisplayName:@"N. California"
               s3StorageDollarsPerGBMonthStandard:.033
                    s3StorageDollarsPerGBMonthRRS:.0264
                             s3UploadDollarsPerGB:.0055
                    s3DataTransferOutDollarsPerGB:.12
                  glacierStorageDollarsPerGBMonth:.011
                        glacierUploadDollarsPerGB:.055
               glacierDataTransferOutDollarsPerGB:.12
                                  supportsGlacier:YES] autorelease];
}
+ (AWSRegion *)usWest2 {
    return [[[AWSRegion alloc] initWithRegionName:@"us-west-2"
                            s3LocationConstraints:[NSArray arrayWithObject:@"us-west-2"]
                                       s3Hostname:@"s3-us-west-2.amazonaws.com"
                                      displayName:@"US West (Oregon)"
                                 shortDisplayName:@"Oregon"
               s3StorageDollarsPerGBMonthStandard:.030
                    s3StorageDollarsPerGBMonthRRS:.024
                             s3UploadDollarsPerGB:.005
                    s3DataTransferOutDollarsPerGB:.12
                  glacierStorageDollarsPerGBMonth:.01
                        glacierUploadDollarsPerGB:.05
               glacierDataTransferOutDollarsPerGB:.12
                                  supportsGlacier:YES] autorelease];
}
+ (AWSRegion *)euWest1 {
    return [[[AWSRegion alloc] initWithRegionName:@"eu-west-1"
                            s3LocationConstraints:[NSArray arrayWithObjects:@"EU", @"eu-west-1", nil]
                                       s3Hostname:@"s3-eu-west-1.amazonaws.com"
                                      displayName:@"EU (Ireland)"
                                 shortDisplayName:@"Ireland"
               s3StorageDollarsPerGBMonthStandard:.030
                    s3StorageDollarsPerGBMonthRRS:.024
                             s3UploadDollarsPerGB:.005
                    s3DataTransferOutDollarsPerGB:.12
                  glacierStorageDollarsPerGBMonth:.011
                        glacierUploadDollarsPerGB:.055
               glacierDataTransferOutDollarsPerGB:.12
                                  supportsGlacier:YES] autorelease];
}
+ (AWSRegion *)apSoutheast1 {
    return [[[AWSRegion alloc] initWithRegionName:@"ap-southeast-1"
                            s3LocationConstraints:[NSArray arrayWithObject:@"ap-southeast-1"]
                                       s3Hostname:@"s3-ap-southeast-1.amazonaws.com"
                                      displayName:@"Asia Pacific (Singapore)"
                                 shortDisplayName:@"Singapore"
               s3StorageDollarsPerGBMonthStandard:.030
                    s3StorageDollarsPerGBMonthRRS:.024
                             s3UploadDollarsPerGB:.005
                    s3DataTransferOutDollarsPerGB:.19
                  glacierStorageDollarsPerGBMonth:0
                        glacierUploadDollarsPerGB:0
               glacierDataTransferOutDollarsPerGB:0
                                  supportsGlacier:NO] autorelease];
}
+ (AWSRegion *)apSoutheast2 {
    return [[[AWSRegion alloc] initWithRegionName:@"ap-southeast-2"
                            s3LocationConstraints:[NSArray arrayWithObject:@"ap-southeast-2"]
                                       s3Hostname:@"s3-ap-southeast-2.amazonaws.com"
                                      displayName:@"Asia Pacific (Sydney)"
                                 shortDisplayName:@"Sydney"
               s3StorageDollarsPerGBMonthStandard:.033
                    s3StorageDollarsPerGBMonthRRS:.0264
                             s3UploadDollarsPerGB:.0055
                    s3DataTransferOutDollarsPerGB:.19
                  glacierStorageDollarsPerGBMonth:.012
                        glacierUploadDollarsPerGB:.06
               glacierDataTransferOutDollarsPerGB:.19
                                  supportsGlacier:YES] autorelease];
}
+ (AWSRegion *)apNortheast1 {
    return [[[AWSRegion alloc] initWithRegionName:@"ap-northeast-1"
                            s3LocationConstraints:[NSArray arrayWithObject:@"ap-northeast-1"]
                                       s3Hostname:@"s3-ap-northeast-1.amazonaws.com"
                                      displayName:@"Asia Pacific (Tokyo)"
                                 shortDisplayName:@"Tokyo"
               s3StorageDollarsPerGBMonthStandard:.033
                    s3StorageDollarsPerGBMonthRRS:.0264
                             s3UploadDollarsPerGB:.005
                    s3DataTransferOutDollarsPerGB:.201
                  glacierStorageDollarsPerGBMonth:.012
                        glacierUploadDollarsPerGB:.06
               glacierDataTransferOutDollarsPerGB:.201
                                  supportsGlacier:YES] autorelease];
}
+ (AWSRegion *)saEast1 {
    return [[[AWSRegion alloc] initWithRegionName:@"sa-east-1"
                            s3LocationConstraints:[NSArray arrayWithObject:@"sa-east-1"]
                                       s3Hostname:@"s3-sa-east-1.amazonaws.com"
                                      displayName:@"South America (Sao Paulo)"
                                 shortDisplayName:@"Sao Paulo"
               s3StorageDollarsPerGBMonthStandard:.0408
                    s3StorageDollarsPerGBMonthRRS:.0326
                             s3UploadDollarsPerGB:.007
                    s3DataTransferOutDollarsPerGB:.25
                  glacierStorageDollarsPerGBMonth:0
                        glacierUploadDollarsPerGB:0
               glacierDataTransferOutDollarsPerGB:0
                                  supportsGlacier:NO] autorelease];
}


- (void)dealloc {
    [regionName release];
    [s3LocationConstraints release];
    [s3Hostname release];
    [displayName release];
    [shortDisplayName release];
    [super dealloc];
}

- (NSString *)regionName {
    return regionName;
}
- (NSString *)displayName {
    return displayName;
}
- (NSString *)shortDisplayName {
    return shortDisplayName;
}
- (NSString *)defaultS3LocationConstraint {
    return [s3LocationConstraints lastObject];
}
- (NSArray *)s3LocationConstraints {
    return s3LocationConstraints;
}
- (double)s3StorageDollarsPerGBMonthStandard {
    return s3StorageDollarsPerGBMonthStandard;
}
- (double)s3StorageDollarsPerGBMonthRRS {
    return s3StorageDollarsPerGBMonthRRS;
}
- (double)s3UploadDollarsPerGB {
    return s3UploadDollarsPerGB;
}
- (double)s3DataTransferOutDollarsPerGB {
    return s3DataTransferOutDollarsPerGB;
}
- (double)glacierStorageDollarsPerGBMonth {
    return glacierStorageDollarsPerGBMonth;
}
- (double)glacierUploadDollarsPerGB {
    return glacierUploadDollarsPerGB;
}
- (double)glacierDataTransferOutDollarsPerGB {
    return glacierDataTransferOutDollarsPerGB;
}
- (NSURL *)s3EndpointWithSSL:(BOOL)useSSL {
    return [NSURL URLWithString:[NSString stringWithFormat:@"http%@://%@", (useSSL ? @"s" : @""), s3Hostname]];
}
- (BOOL)supportsGlacier {
    return supportsGlacier;
}
- (NSString *)glacierEndpointWithSSL:(BOOL)useSSL {
    if (!supportsGlacier) {
        return nil;
    }
    if (getenv("AWS_HOST")) {
        return [NSString stringWithFormat:@"%s/aws/glacier", getenv("AWS_HOST")];
    }
    return [self endpointWithService:@"glacier" useSSL:useSSL];
}
- (NSString *)snsEndpointWithSSL:(BOOL)useSSL {
    if (getenv("AWS_HOST")) {
        return [NSString stringWithFormat:@"%s/aws/sns", getenv("AWS_HOST")];
    }
    return [self endpointWithService:@"sns" useSSL:useSSL];
}
- (NSString *)sqsEndpointWithSSL:(BOOL)useSSL {
    if (getenv("AWS_HOST")) {
        return [NSString stringWithFormat:@"%s/aws/sqs", getenv("AWS_HOST")];
    }
    return [self endpointWithService:@"sqs" useSSL:useSSL];
}


#pragma mark NSObject
- (NSString *)description {
    return [NSString stringWithFormat:@"<AWSRegion %@>", regionName];
}
- (BOOL)isEqual:(id)other {
    if (other == self) {
        return YES;
    }
    if (other == nil || ![other isKindOfClass:[self class]]) {
        return NO;
    }
    return [regionName isEqualToString:[(AWSRegion *)other regionName]];
}
- (NSUInteger)hash {
    return [regionName hash];
}

#pragma mark NSCopying
- (id)copyWithZone:(NSZone *)zone {
    return [[AWSRegion alloc] initWithRegionName:regionName
                           s3LocationConstraints:s3LocationConstraints
                                      s3Hostname:s3Hostname
                                     displayName:displayName
                                shortDisplayName:shortDisplayName
              s3StorageDollarsPerGBMonthStandard:s3StorageDollarsPerGBMonthStandard
                   s3StorageDollarsPerGBMonthRRS:s3StorageDollarsPerGBMonthRRS
                            s3UploadDollarsPerGB:s3UploadDollarsPerGB
                   s3DataTransferOutDollarsPerGB:s3DataTransferOutDollarsPerGB
                 glacierStorageDollarsPerGBMonth:glacierStorageDollarsPerGBMonth
                       glacierUploadDollarsPerGB:glacierUploadDollarsPerGB
              glacierDataTransferOutDollarsPerGB:glacierDataTransferOutDollarsPerGB
                                 supportsGlacier:supportsGlacier];
}


#pragma mark internal
- (id)initWithRegionName:(NSString *)theRegionName
   s3LocationConstraints:(NSArray *)theS3LocationConstraints
              s3Hostname:(NSString *)theS3Hostname
             displayName:(NSString *)theDisplayName
        shortDisplayName:(NSString *)theShortDisplayName
s3StorageDollarsPerGBMonthStandard:(double)theS3StorageDollarsPerGBMonthStandard
  s3StorageDollarsPerGBMonthRRS:(double)theS3StorageDollarsPerGBMonthRRS
    s3UploadDollarsPerGB:(double)theS3UploadDollarsPerGB
s3DataTransferOutDollarsPerGB:(double)theS3DataTransferOutDollarsPerGB
glacierStorageDollarsPerGBMonth:(double)theGlacierStorageDollarsPerGBMonth
glacierUploadDollarsPerGB:(double)theGlacierUploadDollarsPerGB
glacierDataTransferOutDollarsPerGB:(double)theGlacierDataTransferOutDollarsPerGB
         supportsGlacier:(BOOL)theSupportsGlacier {
    if (self = [super init]) {
        regionName = [theRegionName retain];
        s3LocationConstraints = [theS3LocationConstraints retain];
        s3Hostname = [theS3Hostname retain];
        displayName = [theDisplayName retain];
        shortDisplayName = [theShortDisplayName retain];
        s3StorageDollarsPerGBMonthStandard = theS3StorageDollarsPerGBMonthStandard;
        s3StorageDollarsPerGBMonthRRS = theS3StorageDollarsPerGBMonthRRS;
        s3UploadDollarsPerGB = theS3UploadDollarsPerGB;
        s3DataTransferOutDollarsPerGB = theS3DataTransferOutDollarsPerGB;
        glacierStorageDollarsPerGBMonth = theGlacierStorageDollarsPerGBMonth;
        glacierUploadDollarsPerGB = theGlacierUploadDollarsPerGB;
        glacierDataTransferOutDollarsPerGB = theGlacierDataTransferOutDollarsPerGB;
        supportsGlacier = theSupportsGlacier;
    }
    return self;
}

- (NSString *)endpointWithService:(NSString *)theServiceName useSSL:(BOOL)useSSL {
    return [NSString stringWithFormat:@"http%@://%@.%@.amazonaws.com", (useSSL ? @"s" : @""), theServiceName, regionName];
}
@end
