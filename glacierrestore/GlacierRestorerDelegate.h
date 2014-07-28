//
//  GlacierRestorerDelegate.h
//  Arq
//
//  Created by Stefan Reitshamer on 5/29/13.
//  Copyright (c) 2013 Stefan Reitshamer. All rights reserved.
//


@protocol GlacierRestorerDelegate <NSObject>

// Methods return YES if cancel is requested.

- (BOOL)glacierRestorerMessageDidChange:(NSString *)message;

- (BOOL)glacierRestorerBytesRequestedDidChange:(NSNumber *)theRequested;
- (BOOL)glacierRestorerTotalBytesToRequestDidChange:(NSNumber *)theMaxRequested;
- (BOOL)glacierRestorerDidFinishRequesting;

- (BOOL)glacierRestorerBytesTransferredDidChange:(NSNumber *)theTransferred;
- (BOOL)glacierRestorerTotalBytesToTransferDidChange:(NSNumber *)theTotal;

- (BOOL)glacierRestorerErrorMessage:(NSString *)theErrorMessage didOccurForPath:(NSString *)thePath;

- (BOOL)glacierRestorerDidSucceed;
- (BOOL)glacierRestorerDidFail:(NSError *)error;
@end
