//
//  Created by Stefan Reitshamer on 9/23/12.
//
//


@interface AWSRegion : NSObject {
    NSString *regionName;
    NSArray *s3LocationConstraints;
    NSString *s3Hostname;
    NSString *displayName;
    NSString *shortDisplayName;
    double s3StorageDollarsPerGBMonthStandard;
    double s3StorageDollarsPerGBMonthRRS;
    double s3UploadDollarsPerGB;
    double s3DataTransferOutDollarsPerGB;
    double glacierStorageDollarsPerGBMonth;
    double glacierUploadDollarsPerGB;
    double glacierDataTransferOutDollarsPerGB;
    BOOL supportsGlacier;
}

+ (NSArray *)allRegions;
+ (NSArray *)s3Regions;
+ (NSArray *)glacierRegions;
+ (AWSRegion *)regionWithName:(NSString *)theRegionName;
+ (AWSRegion *)regionWithLocation:(NSString *)theLocation;
+ (AWSRegion *)regionWithS3Endpoint:(NSURL *)theEndpoint;
+ (AWSRegion *)usEast1;
+ (AWSRegion *)usWest1;
+ (AWSRegion *)usWest2;
+ (AWSRegion *)euWest1;
+ (AWSRegion *)apSoutheast1;
+ (AWSRegion *)apSoutheast2;
+ (AWSRegion *)apNortheast1;
+ (AWSRegion *)saEast1;

- (NSString *)regionName;
- (NSString *)displayName;
- (NSString *)shortDisplayName;
- (NSString *)defaultS3LocationConstraint;
- (NSArray *)s3LocationConstraints;
- (double)s3StorageDollarsPerGBMonthStandard;
- (double)s3StorageDollarsPerGBMonthRRS;
- (double)s3UploadDollarsPerGB;
- (double)s3DataTransferOutDollarsPerGB;
- (double)glacierStorageDollarsPerGBMonth;
- (double)glacierUploadDollarsPerGB;
- (double)glacierDataTransferOutDollarsPerGB;
- (NSURL *)s3EndpointWithSSL:(BOOL)useSSL;
- (BOOL)supportsGlacier;
- (NSURL *)glacierEndpointWithSSL:(BOOL)useSSL;
- (NSURL *)snsEndpointWithSSL:(BOOL)useSSL;
- (NSURL *)sqsEndpointWithSSL:(BOOL)useSSL;

@end
