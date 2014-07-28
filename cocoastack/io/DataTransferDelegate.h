//
//  DataTransferDelegate.h
//  Arq
//
//  Created by Stefan Reitshamer on 3/19/14.
//  Copyright (c) 2014 Stefan Reitshamer. All rights reserved.
//

@class HTTPThrottle;


@protocol DataTransferDelegate <NSObject>
- (BOOL)dataTransferDidUploadBytes:(uint64_t)count httpThrottle:(HTTPThrottle **)theHTTPThrottle error:(NSError **)error;
- (BOOL)dataTransferDidDownloadBytes:(uint64_t)count httpThrottle:(HTTPThrottle **)theHTTPThrottle error:(NSError **)error;
- (void)dataTransferDidFail;
@end
