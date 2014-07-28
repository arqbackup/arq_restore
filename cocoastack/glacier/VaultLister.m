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
