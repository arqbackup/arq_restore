//
//  S3Region.h
//  Arq
//
//  Created by Stefan Reitshamer on 2/11/12.
//  Copyright 2012 __MyCompanyName__. All rights reserved.
//




@interface S3Region : NSObject {
    NSString *bucketNameSuffix;
    NSString *legacyBucketNameSuffix;
    NSString *locationConstraint;
    NSString *endpoint;
    NSString *displayName;
    double dollarsPerGBMonthStandard;
    double dollarsPerGBMonthRRS;
}
+ (NSArray *)allS3Regions;
+ (S3Region *)s3RegionForBucketName:(NSString *)theBucketName;
+ (S3Region *)usStandard;
+ (S3Region *)usWestNorthernCalifornia;
+ (S3Region *)usWestOregon;
+ (S3Region *)euIreland;
+ (S3Region *)asiaPacificSingapore;
+ (S3Region *)asiaPacificTokyo;
+ (S3Region *)southAmericaSaoPaulo;

- (NSString *)bucketNameSuffix;
- (NSString *)legacyBucketNameSuffix;
- (NSString *)locationConstraint;
- (NSString *)endpoint;
- (NSString *)displayName;
- (double)dollarsPerGBMonthStandard;
- (double)dollarsPerGBMonthRRS;
- (NSString *)bucketNameForAccessKeyID:(NSString *)theAccessKeyID;
@end
