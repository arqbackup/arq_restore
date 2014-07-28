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
