//
//  VaultDeleter.h
//  Arq
//
//  Created by Stefan Reitshamer on 12/1/12.
//  Copyright (c) 2012 Stefan Reitshamer. All rights reserved.
//

@class AWSRegion;
@class GlacierService;
@class SNS;
@class SQS;
@protocol VaultDeleterDelegate;
@class Vault;


@interface VaultDeleter : NSObject {
    Vault *vault;
    GlacierService *glacier;
    SNS *sns;
    SQS *sqs;
    id <VaultDeleterDelegate> delegate;
    NSString *topicArn;
    NSURL *queueURL;
}
- (NSString *)errorDomain;

- (id)initWithVault:(Vault *)theVault glacier:(GlacierService *)theGlacier sns:(SNS *)theSNS sqs:(SQS *)theSQS delegate:(id <VaultDeleterDelegate>)theDelegate;
- (BOOL)deleteVault:(NSError **)error;

@end
