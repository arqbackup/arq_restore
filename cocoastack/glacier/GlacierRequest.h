//
//  GlacierRequest.h
//
//  Created by Stefan Reitshamer on 9/7/12.
//
//

@class GlacierAuthorizationProvider;
@class AWSRegion;
@class GlacierResponse;
@protocol DataTransferDelegate;


@interface GlacierRequest : NSObject {
    NSString *method;
    NSURL *url;
    AWSRegion *awsRegion;
    GlacierAuthorizationProvider *gap;
    BOOL retryOnTransientError;
    id <DataTransferDelegate> dataTransferDelegate;
    NSData *requestData;
    NSMutableDictionary *extraHeaders;
}
- (id)initWithMethod:(NSString *)theMethod url:(NSURL *)theURL awsRegion:(AWSRegion *)theAWSRegion authorizationProvider:(GlacierAuthorizationProvider *)theGAP retryOnTransientError:(BOOL)theRetryOnTransientError dataTransferDelegate:(id <DataTransferDelegate>)theDataTransferDelegate;

- (NSString *)errorDomain;
- (void)setRequestData:(NSData *)thereRuestData;
- (void)setHeader:(NSString *)value forKey:(NSString *)key;
- (GlacierResponse *)execute:(NSError **)error;
@end
