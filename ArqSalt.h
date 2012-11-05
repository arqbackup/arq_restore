//
//  ArqSalt.h
//  Arq
//
//  Created by Stefan Reitshamer on 7/16/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//




@interface ArqSalt : NSObject {
    NSString *accessKeyID;
    NSString *secretAccessKey;
    NSString *s3BucketName;
    NSString *computerUUID;
    NSString *localPath;
    NSString *s3Path;
}
- (id)initWithAccessKeyID:(NSString *)theAccessKeyID
          secretAccessKey:(NSString *)theSecretAccessKey
             s3BucketName:(NSString *)theS3BucketName
             computerUUID:(NSString *)theComputerUUID;
- (NSData *)salt:(NSError **)error;
@end
