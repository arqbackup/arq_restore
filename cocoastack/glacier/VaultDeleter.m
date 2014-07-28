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


#import "VaultDeleter.h"
#import "NSString_extra.h"
#import "GlacierService.h"
#import "SNS.h"
#import "SQS.h"
#import "Vault.h"
#import "ReceiveMessageResponse.h"
#import "SQSMessage.h"
#import "NSString+SBJSON.h"
#import "VaultDeleterDelegate.h"
#import "Vault.h"


#define INITIAL_SLEEP (0.5)
#define SLEEP_GROWTH_FACTOR (2.0)
#define MAX_SLEEP (60.0)
#define MAX_GLACIER_RETRIES (10)


@interface VaultDeleter ()
- (BOOL)deleteArchives:(NSError **)error;
- (void)cleanUp;
@end


@implementation VaultDeleter
- (NSString *)errorDomain {
    return @"VaultDeleterErrorDomain";
}

- (id)initWithVault:(Vault *)theVault glacier:(GlacierService *)theGlacier sns:(SNS *)theSNS sqs:(SQS *)theSQS delegate:(id <VaultDeleterDelegate>)theDelegate {
    if (self = [super init]) {
        vault = [theVault retain];
        glacier = [theGlacier retain];
        sns = [theSNS retain];
        sqs = [theSQS retain];
        delegate = theDelegate;
    }
    return self;
}
- (void)dealloc {
    [vault release];
    [glacier release];
    [sns release];
    [sqs release];
    [topicArn release];
    [queueURL release];
    [super dealloc];
}

- (BOOL)deleteVault:(NSError **)error {
    if ([vault numberOfArchives] > 0) {
        if ([delegate respondsToSelector:@selector(vaultDeleterStatusDidChange:)]) {
            [delegate vaultDeleterStatusDidChange:@"Requesting Glacier inventory"];
        }
        HSLogDebug(@"date: %@\n", [[NSDate date] description]);
        HSLogDebug(@"vault %@ has %ld archives; getting inventory\n", [vault vaultName], (unsigned long)[vault numberOfArchives]);
        BOOL ret = [self deleteArchives:error];
        [self cleanUp];
        if (!ret) {
            return NO;
        }
    }
    
    if (![glacier deleteVaultWithName:[vault vaultName] error:error]) {
        return NO;
    }
    
    return YES;
}


#pragma mark internal
- (BOOL)deleteArchives:(NSError **)error {
    NSString *jobUUID = [NSString stringWithRandomUUID];
    NSString *topicName = [NSString stringWithFormat:@"%@_topic", jobUUID];
    NSString *queueName = [NSString stringWithFormat:@"%@_queue", jobUUID];
    topicArn = [[sns createTopic:topicName error:error] retain];
    if (topicArn == nil) {
        return NO;
    }
    queueURL = [[sqs createQueueWithName:queueName error:error] retain];
    if (queueURL == nil) {
        return NO;
    }
    NSString *queueArn = [sqs queueArnForQueueURL:queueURL error:error];
    if (queueArn == nil) {
        return NO;
    }
    if (![sqs setSendMessagePermissionToQueueURL:queueURL queueArn:queueArn forSourceArn:topicArn error:error]) {
        return NO;
    }
    NSString *subscriptionArn = [sns subscribeQueueArn:queueArn toTopicArn:topicArn error:error];
    if (subscriptionArn == nil) {
        return NO;
    }
    NSString *jobId = [glacier initiateInventoryJobForVaultName:[vault vaultName] snsTopicArn:topicArn error:error];
    if (jobId == nil) {
        return NO;
    }
    
    if ([delegate respondsToSelector:@selector(vaultDeleterStatusDidChange:)]) {
        [delegate vaultDeleterStatusDidChange:@"Waiting (up to 5 hours) for Glacier inventory"];
    }
    NSTimeInterval sleep = INITIAL_SLEEP;
    BOOL ret = YES;
    NSAutoreleasePool *pool = nil;
    for (;;) {
        [pool drain];
        pool = [[NSAutoreleasePool alloc] init];
        if ([delegate respondsToSelector:@selector(vaultDeleterAbortRequestedForVaultName:)] && [delegate vaultDeleterAbortRequestedForVaultName:[vault vaultName]]) {
            ret = NO;
            SETNSERROR([self errorDomain], ERROR_ABORT_REQUESTED, @"abort requested");
            break;
        }
        NSError *myError = nil;
        ReceiveMessageResponse *response = [sqs receiveMessagesForQueueURL:queueURL maxMessages:1 error:&myError];
        if (response == nil) {
            HSLogError(@"error receiving message from queue: %@", myError);
        } else {
            HSLogDebug(@"got %lu messages from queue", (unsigned long)[[response messages] count]);
            for (SQSMessage *msg in [response messages]) {
                HSLogDebug(@"message from queue: %@\n", [msg body]);
            }
            if ([[response messages] count] > 0) {
                break;
            }
        }
        
        if ([[response messages] count] > 0) {
            sleep = INITIAL_SLEEP;
        } else {
            sleep *= SLEEP_GROWTH_FACTOR;
        }
        if (sleep > MAX_SLEEP) {
            sleep = MAX_SLEEP;
        }
        [NSThread sleepForTimeInterval:sleep];
    }
    if (!ret && error != NULL) {
        [*error retain];
    }
    [pool drain];
    if (!ret && error != NULL) {
        [*error autorelease];
    }
    
    if (!ret) {
        return NO;
    }
    
    NSData *inventoryData = [glacier dataForVaultName:[vault vaultName] jobId:jobId retries:MAX_GLACIER_RETRIES error:error];
    if (inventoryData == nil) {
        return NO;
    }
    NSString *inventoryString = [[[NSString alloc] initWithData:inventoryData encoding:NSUTF8StringEncoding] autorelease];
    HSLogDebug(@"inventoryString = %@", inventoryString);
    NSDictionary *json = [inventoryString JSONValue:error];
    if (json == nil) {
        return NO;
    }
    
    id archiveListObj = [json objectForKey:@"ArchiveList"];
    NSArray *theArchiveList = nil;
    if ([archiveListObj isKindOfClass:[NSString class]]) {
        theArchiveList = [archiveListObj JSONValue:error];
        if (theArchiveList == nil) {
            return NO;
        }
    } else {
        theArchiveList = (NSArray *)archiveListObj;
    }
    
    if ([delegate respondsToSelector:@selector(vaultDeleterDidRetrieveArchiveCount:)]) {
        [delegate vaultDeleterDidRetrieveArchiveCount:[theArchiveList count]];
    }
    
    NSUInteger deletedCount = 0;
    for (id archiveObj in theArchiveList) {
        NSDictionary *archiveDict = nil;
        if ([archiveObj isKindOfClass:[NSString class]]) {
            archiveDict = [archiveObj JSONValue:error];
            if (archiveDict == nil) {
                return NO;
            }
        } else if ([archiveObj isKindOfClass:[NSDictionary class]]) {
            archiveDict = (NSDictionary *)archiveObj;
        } else {
            HSLogError(@"unexpected object in ArchiveList");
            SETNSERROR([self errorDomain], -1, @"unexpected object in ArchiveList: %@", archiveObj);
            return NO;
        }
        HSLogDebug(@"archiveDict: %@", archiveDict);
        NSString *archiveId = [archiveDict objectForKey:@"ArchiveId"];
        NSError *myError = nil;
        if (![glacier deleteArchive:archiveId inVault:[vault vaultName] error:&myError]) {
            HSLogError(@"error deleting archive %@: %@", archiveId, myError);
        }
        deletedCount++;
        if ([delegate respondsToSelector:@selector(vaultDeleterDidDeleteArchive)]) {
            [delegate vaultDeleterDidDeleteArchive];
        }
    }
    return YES;
}
- (void)cleanUp {
    NSError *myError = nil;
    if (topicArn != nil && ![sns deleteTopicWithArn:topicArn error:&myError]) {
        HSLogError(@"failed to delete topic %@: %@", topicArn, myError);
    }
    if (queueURL != nil && ![sqs deleteQueue:queueURL error:&myError]) {
        HSLogError(@"failed to delete queue %@: %@", queueURL, myError);
    }
}
@end
