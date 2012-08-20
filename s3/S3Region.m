//
//  S3Region.m
//  Arq
//
//  Created by Stefan Reitshamer on 2/11/12.
//  Copyright 2012 __MyCompanyName__. All rights reserved.
//

#import "S3Region.h"


@interface S3Region (internal)
- (id)initWithBucketNameSuffix:(NSString *)theBucketNameSuffix
        legacyBucketNameSuffix:(NSString *)theLegacyBucketNameSuffix
            locationConstraint:(NSString *)theLocationConstraint
                      endpoint:(NSString *)theEndpoint
                   displayName:(NSString *)theDisplayName
     dollarsPerGBMonthStandard:(double)theDollarsPerGBMonthStandard
          dollarsPerGBMonthRRS:(double)theDollarsPerGBMonthRRS;
@end

@implementation S3Region
+ (NSArray *)allS3Regions {
    NSMutableArray *ret = [NSMutableArray array];
    [ret addObject:[S3Region usStandard]];
    [ret addObject:[S3Region usWestNorthernCalifornia]];
    [ret addObject:[S3Region usWestOregon]];
    [ret addObject:[S3Region euIreland]];
    [ret addObject:[S3Region asiaPacificSingapore]];
    [ret addObject:[S3Region asiaPacificTokyo]];
    [ret addObject:[S3Region southAmericaSaoPaulo]];
    return ret;
}
+ (S3Region *)s3RegionForBucketName:(NSString *)theBucketName {
    for (S3Region *region in [S3Region allS3Regions]) {
        if ([[region bucketNameSuffix] length] > 0 && ([theBucketName hasSuffix:[region bucketNameSuffix]] || [theBucketName hasSuffix:[region legacyBucketNameSuffix]])) {
            return region;
        }
    }
    return [S3Region usStandard];
}
+ (S3Region *)usStandard {
    return [[[S3Region alloc] initWithBucketNameSuffix:@"" 
                                legacyBucketNameSuffix:@""
                                    locationConstraint:nil 
                                              endpoint:@"s3.amazonaws.com" 
                                           displayName:@"US Standard"
                             dollarsPerGBMonthStandard:.125 
                                  dollarsPerGBMonthRRS:.093] autorelease];
}
+ (S3Region *)usWestNorthernCalifornia {
    return [[[S3Region alloc] initWithBucketNameSuffix:@"-us-west-1" 
                                legacyBucketNameSuffix:@"us-west-1"
                                    locationConstraint:@"us-west-1" 
                                              endpoint:@"s3-us-west-1.amazonaws.com"
                                           displayName:@"US West (Northern California)" 
                             dollarsPerGBMonthStandard:.140 
                                  dollarsPerGBMonthRRS:.103] autorelease];
}
+ (S3Region *)usWestOregon {
    return [[[S3Region alloc] initWithBucketNameSuffix:@"-us-west-2" 
                                legacyBucketNameSuffix:@"us-west-2"
                                    locationConstraint:@"us-west-2" 
                                              endpoint:@"s3-us-west-2.amazonaws.com"
                                           displayName:@"US West (Oregon)" 
                             dollarsPerGBMonthStandard:.125 
                                  dollarsPerGBMonthRRS:.093] autorelease];
}
+ (S3Region *)euIreland {
    return [[[S3Region alloc] initWithBucketNameSuffix:@"-eu" 
                                legacyBucketNameSuffix:@"eu"
                                    locationConstraint:@"EU"
                                              endpoint:@"s3-eu-west-1.amazonaws.com"
                                           displayName:@"EU (Ireland)" 
                             dollarsPerGBMonthStandard:.125 
                                  dollarsPerGBMonthRRS:.093] autorelease];
}
+ (S3Region *)asiaPacificSingapore {
    return [[[S3Region alloc] initWithBucketNameSuffix:@"-ap-southeast-1" 
                                legacyBucketNameSuffix:@"ap-southeast-1"
                                    locationConstraint:@"ap-southeast-1" 
                                              endpoint:@"s3-ap-southeast-1.amazonaws.com" 
                                           displayName:@"Asia Pacific (Singapore)" 
                             dollarsPerGBMonthStandard:.125 
                                  dollarsPerGBMonthRRS:.093] autorelease];
}
+ (S3Region *)asiaPacificTokyo {
    return [[[S3Region alloc] initWithBucketNameSuffix:@"-ap-northeast-1" 
                                legacyBucketNameSuffix:@"ap-northeast-1"
                                    locationConstraint:@"ap-northeast-1" 
                                              endpoint:@"s3-ap-northeast-1.amazonaws.com" 
                                           displayName:@"Asia Pacific (Tokyo)" 
                             dollarsPerGBMonthStandard:.130 
                                  dollarsPerGBMonthRRS:.100] autorelease];
}
+ (S3Region *)southAmericaSaoPaulo {
    return [[[S3Region alloc] initWithBucketNameSuffix:@"-sa-east-1" 
                                legacyBucketNameSuffix:@"sa-east-1"
                                    locationConstraint:@"sa-east-1" 
                                              endpoint:@"s3-sa-east-1.amazonaws.com" 
                                           displayName:@"South America (Sao Paulo)" 
                             dollarsPerGBMonthStandard:.170 
                                  dollarsPerGBMonthRRS:.127] autorelease];
}


- (void)dealloc {
    [bucketNameSuffix release];
    [displayName release];
    [super dealloc];
}

- (NSString *)bucketNameSuffix {
    return bucketNameSuffix;
}
- (NSString *)legacyBucketNameSuffix {
    return legacyBucketNameSuffix;
}
- (NSString *)locationConstraint {
    return locationConstraint;
}
- (NSString *)endpoint {
    return endpoint;
}
- (NSString *)displayName {
    return displayName;
}
- (double)dollarsPerGBMonthStandard {
    return dollarsPerGBMonthStandard;
}
- (double)dollarsPerGBMonthRRS {
    return dollarsPerGBMonthRRS;
}
- (NSString *)bucketNameForAccessKeyID:(NSString *)theAccessKeyID {
    return [[theAccessKeyID lowercaseString] stringByAppendingFormat:@"comhaystacksoftwarearq%@", bucketNameSuffix];
}

- (NSString *)description {
    return displayName;
}
@end

@implementation S3Region (internal)
- (id)initWithBucketNameSuffix:(NSString *)theBucketNameSuffix
        legacyBucketNameSuffix:(NSString *)theLegacyBucketNameSuffix
            locationConstraint:(NSString *)theLocationConstraint
                      endpoint:(NSString *)theEndpoint
                   displayName:(NSString *)theDisplayName
     dollarsPerGBMonthStandard:(double)theDollarsPerGBMonthStandard
          dollarsPerGBMonthRRS:(double)theDollarsPerGBMonthRRS {
    if (self = [super init]) {
        bucketNameSuffix = [theBucketNameSuffix retain];
        legacyBucketNameSuffix = [theLegacyBucketNameSuffix retain];
        locationConstraint = [theLocationConstraint retain];
        endpoint = [theEndpoint retain];
        displayName = [theDisplayName retain];
        dollarsPerGBMonthStandard = theDollarsPerGBMonthStandard;
        dollarsPerGBMonthRRS = theDollarsPerGBMonthRRS;
    }
    return self;
}
@end
