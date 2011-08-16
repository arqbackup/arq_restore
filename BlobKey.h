//
//  BlobKey.h
//  Arq
//
//  Created by Stefan Reitshamer on 6/27/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface BlobKey : NSObject <NSCopying> {
    NSString *sha1;
    BOOL stretchEncryptionKey;
}
- (id)initWithSHA1:(NSString *)theSHA1 stretchEncryptionKey:(BOOL)isStretchedKey;
- (NSString *)sha1;
- (BOOL)stretchEncryptionKey;
@end
