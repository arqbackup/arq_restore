//
//  ReflogEntry.m
//  arq_restore
//
//  Created by Stefan Reitshamer on 11/20/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "ReflogEntry.h"
#import "BlobKey.h"
#import "DictNode.h"
#import "SetNSError.h"


@implementation ReflogEntry
- (id)initWithData:(NSData *)theData error:(NSError **)error {
    if (self = [super init]) {
        DictNode *dictNode = [DictNode dictNodeWithXMLData:theData error:error];
        if (dictNode == nil) {
            [self release];
            return nil;
        }
        if (![dictNode containsKey:@"oldHeadSHA1"]
            || ![dictNode containsKey:@"oldHeadStretchKey"]
            || ![dictNode containsKey:@"newHeadSHA1"]
            || ![dictNode containsKey:@"newHeadStretchKey"]) {
            SETNSERROR(@"ReflogEntryErrorDomain", -1, @"missing values in reflog entry");
            [self release];
            return nil;
        }
        oldHeadBlobKey = [[BlobKey alloc] initWithSHA1:[[dictNode stringNodeForKey:@"oldHeadSHA1"] stringValue]
                                           storageType:StorageTypeS3
                                  stretchEncryptionKey:[[dictNode booleanNodeForKey:@"oldHeadStretchKey"] booleanValue]
                                            compressed:NO];
        
        newHeadBlobKey = [[BlobKey alloc] initWithSHA1:[[dictNode stringNodeForKey:@"newHeadSHA1"] stringValue]
                                           storageType:StorageTypeS3
                                  stretchEncryptionKey:[[dictNode booleanNodeForKey:@"newHeadStretchKey"] booleanValue]
                                            compressed:NO];
    }
    return self;
}
- (void)dealloc {
    [oldHeadBlobKey release];
    [newHeadBlobKey release];
    [super dealloc];
}

- (BlobKey *)oldHeadBlobKey  {
    return oldHeadBlobKey;
}
- (BlobKey *)newHeadBlobKey {
    return newHeadBlobKey;
}
@end
