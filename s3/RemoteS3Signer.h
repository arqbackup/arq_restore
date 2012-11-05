//
//  RemoteS3Signer.h
//  Arq
//
//  Created by Stefan Reitshamer on 12/30/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//


#import "S3Signer.h"

@interface RemoteS3Signer : NSObject <S3Signer> {
    NSString *accessKey;
    NSURL *url;
    NSString *account;
    NSString *password;
}
+ (NSString *)errorDomain;
- (id)initWithAccessKey:(NSString *)theAccessKey url:(NSURL *)theURL account:(NSString *)theAccount password:(NSString *)thePassword;
@end
