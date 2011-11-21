//
//  ReflogEntry.h
//  arq_restore
//
//  Created by Stefan Reitshamer on 11/20/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
@class BlobKey;

@interface ReflogEntry : NSObject {
    BlobKey *oldHeadBlobKey;
    BlobKey *newHeadBlobKey;
}
- (id)initWithData:(NSData *)theData error:(NSError **)error;

- (BlobKey *)oldHeadBlobKey;
- (BlobKey *)newHeadBlobKey;
@end
