//
//  VaultLister.m
//  Arq
//
//  Created by Stefan Reitshamer on 9/11/12.
//
//

#import "VaultLister.h"
#import "GlacierRequest.h"
#import "GlacierResponse.h"
#import "NSString+SBJSON.h"
#import "Vault.h"
#import "AWSRegion.h"


@interface VaultLister ()
- (BOOL)get:(NSError **)error;
@end

@implementation VaultLister
- (id)initWithGlacierAuthorizationProvider:(GlacierAuthorizationProvider *)theGAP awsRegion:(AWSRegion *)theAWSRegion useSSL:(BOOL)theUseSSL retryOnTransientError:(BOOL)retry {
    if (self = [super init]) {
        gap = [theGAP retain];
        awsRegion = [theAWSRegion retain];
        useSSL = theUseSSL;
        retryOnTransientError = retry;
        vaults = [[NSMutableArray alloc] init];
    }
    return self;
}
- (void)dealloc {
    [gap release];
    [awsRegion release];
    [marker release];
    [vaults release];
    [super dealloc];
}
- (NSArray *)vaults:(NSError **)error {
    for (;;) {
        if (![self get:error]) {
            return nil;
        }
        if (marker == nil) {
            break;
        }
    }
    return vaults;
}


#pragma mark internal
- (BOOL)get:(NSError **)error {
    NSString *urlString = [NSString stringWithFormat:@"%@/-/vaults", [awsRegion glacierEndpointWithSSL:useSSL]];
    if (marker != nil) {
        urlString = [urlString stringByAppendingFormat:@"?marker=%@", marker];
    }
    NSURL *theURL = [NSURL URLWithString:urlString];
    
    GlacierRequest *req = [[[GlacierRequest alloc] initWithMethod:@"GET" url:theURL awsRegion:awsRegion authorizationProvider:gap retryOnTransientError:retryOnTransientError dataTransferDelegate:nil] autorelease];
    [req setHeader:@"application/json" forKey:@"Accept"];
    [req setHeader:@"Glacier.ListVaults" forKey:@"x-amz-target"];
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
    NSArray *vaultList = [dict objectForKey:@"VaultList"];
    for (NSDictionary *vaultDict in vaultList) {
        Vault *vault = [[[Vault alloc] initWithAWSRegion:awsRegion json:vaultDict] autorelease];
        [vaults addObject:vault];
    }
    return YES;
}
@end
