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

@class Vault;
@class GlacierAuthorizationProvider;
@class AWSRegion;
@protocol DataTransferDelegate;


enum {
    GLACIER_ERROR_UNEXPECTED_RESPONSE = -51001,
    GLACIER_ERROR_AMAZON_ERROR = -51002,
    GLACIER_INVALID_PARAMETERS = -51003
};


@interface GlacierService : NSObject {
    GlacierAuthorizationProvider *gap;
    AWSRegion *awsRegion;
    BOOL useSSL;
    BOOL retryOnTransientError;
}
+ (NSString *)errorDomain;

- (id)initWithGlacierAuthorizationProvider:(GlacierAuthorizationProvider *)theGAP awsRegion:(AWSRegion *)theAWSRegion useSSL:(BOOL)theUseSSL retryOnTransientError:(BOOL)retry;

- (NSArray *)vaults:(NSError **)error;
- (Vault *)vaultWithName:(NSString *)theVaultName error:(NSError **)error;
- (BOOL)createVaultWithName:(NSString *)theName error:(NSError **)error;
- (BOOL)deleteVaultWithName:(NSString *)theName error:(NSError **)error;
- (NSString *)uploadArchive:(NSData *)data toVaultName:(NSString *)theVaultName error:(NSError **)error;
- (NSString *)uploadArchive:(NSData *)data toVaultName:(NSString *)theVaultName dataTransferDelegate:(id <DataTransferDelegate>)theDelegate error:(NSError **)error;
- (BOOL)deleteArchive:(NSString *)theArchiveId inVault:(NSString *)theVaultName error:(NSError **)error;
- (NSString *)initiateRetrievalJobForVaultName:(NSString *)theVaultName archiveId:(NSString *)theArchiveId snsTopicArn:(NSString *)theSNSTopicArn error:(NSError **)error;
- (NSString *)initiateInventoryJobForVaultName:(NSString *)theVaultName snsTopicArn:(NSString *)theSNSTopicArn error:(NSError **)error;
- (NSArray *)jobsForVaultName:(NSString *)theVaultName error:(NSError **)error;
- (NSData *)dataForVaultName:(NSString *)theVaultName jobId:(NSString *)theJobId retries:(NSUInteger)theRetries error:(NSError **)error;
@end
