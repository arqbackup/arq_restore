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
