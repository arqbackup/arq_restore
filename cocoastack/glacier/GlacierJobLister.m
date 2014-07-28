//
//  GlacierJobLister.m
//
//  Created by Stefan Reitshamer on 9/17/12.
//
//

#import "GlacierJobLister.h"
#import "GlacierRequest.h"
#import "GlacierResponse.h"
#import "AWSRegion.h"
#import "NSString+SBJSON.h"
#import "GlacierJob.h"


@interface GlacierJobLister ()
- (BOOL)get:(NSError **)error;
@end

@implementation GlacierJobLister
- (id)initWithGlacierAuthorizationProvider:(GlacierAuthorizationProvider *)theGAP vaultName:(NSString *)theVaultName awsRegion:(AWSRegion *)theAWSRegion useSSL:(BOOL)theUseSSL retryOnTransientError:(BOOL)retry {
    if (self = [super init]) {
        gap = [theGAP retain];
        vaultName = [theVaultName retain];
        awsRegion = [theAWSRegion retain];
        useSSL = theUseSSL;
        retryOnTransientError = retry;
        jobs = [[NSMutableArray alloc] init];
    }
    return self;
}
- (void)dealloc {
    [gap release];
    [vaultName release];
    [awsRegion release];
    [marker release];
    [jobs release];
    [super dealloc];
}
- (NSArray *)jobs:(NSError **)error {
    for (;;) {
        if (![self get:error]) {
            return nil;
        }
        if (marker == nil) {
            break;
        }
    }
    return jobs;
}


#pragma mark internal
- (BOOL)get:(NSError **)error {
    NSString *urlString = [NSString stringWithFormat:@"%@/-/vaults/%@/jobs", [awsRegion glacierEndpointWithSSL:useSSL], vaultName];
    if (marker != nil) {
        urlString = [urlString stringByAppendingFormat:@"marker=%@", marker];
    }
    NSURL *theURL = [NSURL URLWithString:urlString];
    
    GlacierRequest *req = [[[GlacierRequest alloc] initWithMethod:@"GET" url:theURL awsRegion:awsRegion authorizationProvider:gap retryOnTransientError:retryOnTransientError dataTransferDelegate:nil] autorelease];
    GlacierResponse *response = [req execute:error];
    if (response == nil) {
        return NO;
    }
    NSData *data = [response body];
    NSString *responseString = [[[NSString alloc] initWithBytes:[data bytes] length:[data length] encoding:NSUTF8StringEncoding] autorelease];
    NSDictionary *dict = [responseString JSONValue:error];
    [marker release];
    marker = [[dict objectForKey:@"Marker"] retain];
    if ([marker isKindOfClass:[NSNull class]]) {
        [marker release];
        marker = nil;
    }
    NSArray *jobList = [dict objectForKey:@"JobList"];
    for (NSDictionary *jobDict in jobList) {
        GlacierJob *job = [[[GlacierJob alloc] initWithAWSRegion:awsRegion vaultName:vaultName json:jobDict] autorelease];
        [jobs addObject:job];
    }
    return YES;
}
@end
