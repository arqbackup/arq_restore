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

#import "GlacierService.h"
#import "AWSRegion.h"
#import "GlacierRequest.h"
#import "NSString+SBJSON.h"
#import "NSObject+SBJSON.h"
#import "Vault.h"
#import "SHA256Hash.h"
#import "GlacierResponse.h"
#import "VaultLister.h"
#import "NSString_extra.h"
#import "SHA256TreeHash.h"
#import "GlacierJobLister.h"

#define MAX_JOB_DOWNLOAD_RETRIES (10)


@implementation GlacierService
+ (NSString *)errorDomain {
    return @"GlacierServiceErrorDomain";
}

- (id)initWithGlacierAuthorizationProvider:(GlacierAuthorizationProvider *)theGAP awsRegion:(AWSRegion *)theAWSRegion useSSL:(BOOL)theUseSSL retryOnTransientError:(BOOL)retry {
    if (self = [super init]) {
        gap = [theGAP retain];
        awsRegion = [theAWSRegion retain];
        useSSL = theUseSSL;
        retryOnTransientError = retry;
    }
    return self;
}
- (void)dealloc {
    [gap release];
    [super dealloc];
}

- (NSArray *)vaults:(NSError **)error {
    VaultLister *lister = [[[VaultLister alloc] initWithGlacierAuthorizationProvider:gap awsRegion:awsRegion useSSL:useSSL retryOnTransientError:retryOnTransientError] autorelease];
    return [lister vaults:error];
}
- (Vault *)vaultWithName:(NSString *)theVaultName error:(NSError **)error {
    NSURL *theURL =[NSURL URLWithString:[NSString stringWithFormat:@"%@/-/vaults/%@", [awsRegion glacierEndpointWithSSL:useSSL], theVaultName]];
    GlacierRequest *req = [[[GlacierRequest alloc] initWithMethod:@"GET" url:theURL awsRegion:awsRegion authorizationProvider:gap retryOnTransientError:retryOnTransientError dataTransferDelegate:nil] autorelease];
    [req setHeader:@"application/json" forKey:@"Accept"];
    [req setHeader:@"application/x-amz-json-1.0" forKey:@"Content-Type"];
    [req setHeader:@"Glacier.DescribeVault" forKey:@"x-amz-target"];
    GlacierResponse *response = [req execute:error];
    if (response == nil) {
        return nil;
    }
    NSData *data = [response body];
    NSString *responseString = [[[NSString alloc] initWithBytes:[data bytes] length:[data length] encoding:NSUTF8StringEncoding] autorelease];
    NSDictionary *dict = [responseString JSONValue:error];
    if (dict == nil) {
        return nil;
    }
    return [[[Vault alloc] initWithAWSRegion:awsRegion json:dict] autorelease];
}
- (BOOL)createVaultWithName:(NSString *)theName error:(NSError **)error {
    NSURL *theURL =[NSURL URLWithString:[NSString stringWithFormat:@"%@/-/vaults/%@", [awsRegion glacierEndpointWithSSL:useSSL], theName]];
    GlacierRequest *req = [[[GlacierRequest alloc] initWithMethod:@"PUT" url:theURL awsRegion:awsRegion authorizationProvider:gap retryOnTransientError:retryOnTransientError dataTransferDelegate:nil] autorelease];
    
    NSData *requestData = [NSData data];
    [req setRequestData:requestData];
    [req setHeader:[NSString stringWithFormat:@"%ld", (unsigned long)[requestData length]] forKey:@"Content-Length"];

    [req setHeader:@"application/json" forKey:@"Accept"];
    [req setHeader:@"application/x-amz-json-1.0" forKey:@"Content-Type"];
    [req setHeader:@"Glacier.CreateVault" forKey:@"x-amz-target"];
    [req setHeader:[NSString hexStringWithData:[SHA256Hash hashData:requestData]] forKey:@"x-amz-content-sha256"];

    
    GlacierResponse *response = [req execute:error];
    if (response == nil) {
        return NO;
    }
    return YES;
}
- (BOOL)deleteVaultWithName:(NSString *)theName error:(NSError **)error {
    NSURL *theURL =[NSURL URLWithString:[NSString stringWithFormat:@"%@/-/vaults/%@", [awsRegion glacierEndpointWithSSL:useSSL], theName]];
    GlacierRequest *req = [[[GlacierRequest alloc] initWithMethod:@"DELETE" url:theURL awsRegion:awsRegion authorizationProvider:gap retryOnTransientError:retryOnTransientError dataTransferDelegate:nil] autorelease];
    
    [req setHeader:@"application/json" forKey:@"Accept"];
    [req setHeader:@"application/x-amz-json-1.0" forKey:@"Content-Type"];
    [req setHeader:@"Glacier.DeleteVault" forKey:@"x-amz-target"];
    
    NSError *myError = nil;
    GlacierResponse *response = [req execute:&myError];
    if (response == nil) {
        if ([myError isErrorWithDomain:[req errorDomain] code:GLACIER_ERROR_AMAZON_ERROR]
            && [[[myError userInfo] objectForKey:@"AmazonCode"] isEqualToString:@"InvalidParameterValueException"]
            && [[[[myError userInfo] objectForKey:@"AmazonMessage"] lowercaseString] hasPrefix:@"vault not empty"]) {
            HSLogError(@"%@", myError);
            SETNSERROR([GlacierService errorDomain], ERROR_GLACIER_VAULT_INVENTORY_NOT_UP_TO_DATE, @"Failed to delete the Glacier vault. Please wait 24 hours, select 'Legacy Glacier Vaults', and try again.");
        } else {
            SETERRORFROMMYERROR;
        }
        return NO;
    }
    return YES;
}
- (NSString *)uploadArchive:(NSData *)data toVaultName:(NSString *)theVaultName error:(NSError **)error {
    return [self uploadArchive:data toVaultName:theVaultName dataTransferDelegate:nil error:error];
}
- (NSString *)uploadArchive:(NSData *)data toVaultName:(NSString *)theVaultName dataTransferDelegate:(id <DataTransferDelegate>)theDelegate error:(NSError **)error {
    NSURL *theURL =[NSURL URLWithString:[NSString stringWithFormat:@"%@/-/vaults/%@/archives", [awsRegion glacierEndpointWithSSL:useSSL], theVaultName]];
    GlacierRequest *req = [[[GlacierRequest alloc] initWithMethod:@"POST" url:theURL awsRegion:awsRegion authorizationProvider:gap retryOnTransientError:retryOnTransientError dataTransferDelegate:theDelegate] autorelease];
    [req setHeader:[NSString hexStringWithData:[SHA256Hash hashData:data]] forKey:@"x-amz-content-sha256"];
    [req setHeader:[NSString stringWithFormat:@"%ld", (long)[data length]] forKey:@"Content-Length"];
    [req setHeader:[NSString hexStringWithData:[SHA256TreeHash treeHashOfData:data]] forKey:@"x-amz-sha256-tree-hash"];
    [req setRequestData:data];
    
    GlacierResponse *response = [req execute:error];
    if (response == nil) {
        return nil;
    }
    NSString *ret = [response headerForKey:@"x-amz-archive-id"];
    if (ret == nil) {
        HSLogError(@"missing x-amz-archive-id header in glacier response headers %@", [response headers]);
        SETNSERROR([req errorDomain], -1, @"missing x-amz-archive-id header in glacier response");
    }
    return ret;
}
- (BOOL)deleteArchive:(NSString *)theArchiveId inVault:(NSString *)theVaultName error:(NSError **)error {
    NSURL *theURL =[NSURL URLWithString:[NSString stringWithFormat:@"%@/-/vaults/%@/archives/%@", [awsRegion glacierEndpointWithSSL:useSSL], theVaultName, theArchiveId]];
    GlacierRequest *req = [[[GlacierRequest alloc] initWithMethod:@"DELETE" url:theURL awsRegion:awsRegion authorizationProvider:gap retryOnTransientError:retryOnTransientError dataTransferDelegate:nil] autorelease];
    
    GlacierResponse *response = [req execute:error];
    if (response == nil) {
        return NO;
    }
    return YES;
}
- (NSString *)initiateRetrievalJobForVaultName:(NSString *)theVaultName archiveId:(NSString *)theArchiveId snsTopicArn:(NSString *)theSNSTopicArn error:(NSError **)error {
    NSMutableDictionary *args = [NSMutableDictionary dictionary];
    [args setObject:@"archive-retrieval" forKey:@"Type"];
    [args setObject:theArchiveId forKey:@"ArchiveId"];
    [args setObject:[NSString stringWithFormat:@"Retrieve archive %@", theArchiveId] forKey:@"Description"];
    [args setObject:theSNSTopicArn forKey:@"SNSTopic"];
    
    NSData *requestData = [[args JSONRepresentation:error] dataUsingEncoding:NSUTF8StringEncoding];
    if (requestData == nil) {
        return nil;
    }
    
    NSURL *theURL =[NSURL URLWithString:[NSString stringWithFormat:@"%@/-/vaults/%@/jobs", [awsRegion glacierEndpointWithSSL:useSSL], theVaultName]];
    GlacierRequest *req = [[[GlacierRequest alloc] initWithMethod:@"POST" url:theURL awsRegion:awsRegion authorizationProvider:gap retryOnTransientError:retryOnTransientError dataTransferDelegate:nil] autorelease];
    [req setHeader:[NSString stringWithFormat:@"%ld", (long)[requestData length]] forKey:@"Content-Length"];
    [req setRequestData:requestData];
    
    GlacierResponse *response = [req execute:error];
    if (response == nil) {
        return nil;
    }
    NSString *ret = [response headerForKey:@"x-amz-job-id"];
    if (ret == nil) {
        SETNSERROR([GlacierService errorDomain], -1, @"missing x-amz-job-id header in response");
    }
    return ret;
}
- (NSString *)initiateInventoryJobForVaultName:(NSString *)theVaultName snsTopicArn:(NSString *)theSNSTopicArn error:(NSError **)error {
    NSMutableDictionary *args = [NSMutableDictionary dictionary];
    [args setObject:@"inventory-retrieval" forKey:@"Type"];
    [args setObject:[NSString stringWithFormat:@"Inventory vault %@", theVaultName] forKey:@"Description"];
    [args setObject:@"JSON" forKey:@"Format"];
    [args setObject:theSNSTopicArn forKey:@"SNSTopic"];
    
    NSData *requestData = [[args JSONRepresentation:error] dataUsingEncoding:NSUTF8StringEncoding];
    if (requestData == nil) {
        return nil;
    }
    
    NSURL *theURL =[NSURL URLWithString:[NSString stringWithFormat:@"%@/-/vaults/%@/jobs", [awsRegion glacierEndpointWithSSL:useSSL], theVaultName]];
    GlacierRequest *req = [[[GlacierRequest alloc] initWithMethod:@"POST" url:theURL awsRegion:awsRegion authorizationProvider:gap retryOnTransientError:retryOnTransientError dataTransferDelegate:nil] autorelease];
    [req setHeader:[NSString stringWithFormat:@"%ld", (long)[requestData length]] forKey:@"Content-Length"];
    [req setRequestData:requestData];
    
    GlacierResponse *response = [req execute:error];
    if (response == nil) {
        return nil;
    }
    NSString *ret = [response headerForKey:@"x-amz-job-id"];
    if (ret == nil) {
        SETNSERROR([GlacierService errorDomain], -1, @"missing x-amz-job-id header in response");
    }
    return ret;
}
- (NSArray *)jobsForVaultName:(NSString *)theVaultName error:(NSError **)error {
    GlacierJobLister *lister = [[[GlacierJobLister alloc] initWithGlacierAuthorizationProvider:gap vaultName:theVaultName awsRegion:awsRegion useSSL:useSSL retryOnTransientError:retryOnTransientError] autorelease];
    return [lister jobs:error];
}
- (NSData *)dataForVaultName:(NSString *)theVaultName jobId:(NSString *)theJobId retries:(NSUInteger)theRetries error:(NSError **)error {
    NSURL *theURL =[NSURL URLWithString:[NSString stringWithFormat:@"%@/-/vaults/%@/jobs/%@/output", [awsRegion glacierEndpointWithSSL:useSSL], theVaultName, theJobId]];
    NSData *ret = nil;
    
    NSError *myError = nil;
    for (NSUInteger i = 0; i < theRetries; i++) {
        GlacierRequest *req = [[[GlacierRequest alloc] initWithMethod:@"GET" url:theURL awsRegion:awsRegion authorizationProvider:gap retryOnTransientError:retryOnTransientError dataTransferDelegate:nil] autorelease];
        [req setHeader:@"2012-06-01" forKey:@"x-amz-glacier-version"];
        
        GlacierResponse *response = [req execute:&myError];
        if (response != nil) {
            ret = [response body];
            break;
        }
        
        HSLogError(@"failed to get data for %@ job %@ (retrying): %@", theVaultName, theJobId, [myError localizedDescription]);
        [NSThread sleepForTimeInterval:5.0];
    }
    if (ret == nil) {
        SETERRORFROMMYERROR;
    }
    return ret;
}

@end
