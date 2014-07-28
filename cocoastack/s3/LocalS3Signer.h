//
//  LocalS3Signer.h
//  Arq
//
//  Created by Stefan Reitshamer on 12/30/10.
//  Copyright 2010 Haystack Software. All rights reserved.
//


#import "S3Signer.h"

@interface LocalS3Signer : NSObject <S3Signer> {
    NSString *secretKey;
}
- (id)initWithSecretKey:(NSString *)theSecretKey;
@end
