//
//  ArqRepo_Verifier.h
//  arq_restore
//
//  Created by Stefan Reitshamer on 8/19/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "ArqRepo.h"

@interface ArqRepo (Verifier)
- (NSString *)blobsPackSetName;
- (BOOL)packSHA1:(NSString **)packSHA1 forPackedBlobSHA1:(NSString *)sha1 error:(NSError **)error;
@end
