//
//  S3GlacierRestorerDelegate.h
//  Arq
//
//  Created by Stefan Reitshamer on 1/9/14.
//  Copyright (c) 2014 Stefan Reitshamer. All rights reserved.
//


@protocol S3GlacierRestorerDelegate <NSObject>

// Methods return YES if cancel is requested.

- (BOOL)s3GlacierRestorerMessageDidChange:(NSString *)message;

- (BOOL)s3GlacierRestorerBytesRequestedDidChange:(NSNumber *)theRequested;
- (BOOL)s3GlacierRestorerTotalBytesToRequestDidChange:(NSNumber *)theMaxRequested;
- (BOOL)s3GlacierRestorerDidFinishRequesting;

- (BOOL)s3GlacierRestorerBytesTransferredDidChange:(NSNumber *)theTransferred;
- (BOOL)s3GlacierRestorerTotalBytesToTransferDidChange:(NSNumber *)theTotal;

- (BOOL)s3GlacierRestorerErrorMessage:(NSString *)theErrorMessage didOccurForPath:(NSString *)thePath;

- (void)s3GlacierRestorerDidSucceed;
- (void)s3GlacierRestorerDidFail:(NSError *)error;

@end
