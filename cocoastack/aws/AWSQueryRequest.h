//
//  Created by Stefan Reitshamer on 9/16/12.
//
//

@class AWSQueryResponse;


@interface AWSQueryRequest : NSObject {
    NSString *method;
    NSURL *url;
    BOOL retryOnTransientError;
}
- (id)initWithMethod:(NSString *)theMethod url:(NSURL *)theURL retryOnTransientError:(BOOL)theRetryOnTransientError;

- (NSString *)errorDomain;
- (AWSQueryResponse *)execute:(NSError **)error;
@end
