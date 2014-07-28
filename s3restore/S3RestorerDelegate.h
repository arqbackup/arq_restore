//
//  S3RestorerDelegate.h
//  Arq
//
//  Created by Stefan Reitshamer on 5/28/13.
//  Copyright (c) 2013 Stefan Reitshamer. All rights reserved.
//

@protocol S3RestorerDelegate <NSObject>

// Methods return YES if cancel is requested.

- (BOOL)s3RestorerMessageDidChange:(NSString *)message;

- (BOOL)s3RestorerBytesTransferredDidChange:(NSNumber *)theTransferred;
- (BOOL)s3RestorerTotalBytesToTransferDidChange:(NSNumber *)theTotal;

- (BOOL)s3RestorerErrorMessage:(NSString *)theErrorMessage didOccurForPath:(NSString *)thePath;

- (BOOL)s3RestorerDidSucceed;
- (BOOL)s3RestorerDidFail:(NSError *)error;
@end
