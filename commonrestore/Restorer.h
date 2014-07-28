//
//  Restorer.h
//  Arq
//
//  Created by Stefan Reitshamer on 6/12/13.
//  Copyright (c) 2013 Stefan Reitshamer. All rights reserved.
//

@class BlobKey;


@protocol Restorer <NSObject>
- (NSString *)errorDomain;
- (BOOL)requestBlobKey:(BlobKey *)theBlobKey error:(NSError **)error;
- (NSNumber *)isObjectAvailableForBlobKey:(BlobKey *)theBlobKey error:(NSError **)error;
- (NSNumber *)sizeOfBlob:(BlobKey *)theBlobKey error:(NSError **)error;
- (NSData *)dataForBlobKey:(BlobKey *)theBlobKey error:(NSError **)error;
- (BOOL)shouldSkipFile:(NSString *)thePath;
- (BOOL)useTargetUIDAndGID;
- (uid_t)targetUID;
- (gid_t)targetGID;
@end
