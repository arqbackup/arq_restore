//
//  ArqRepo_Verifier.m
//  arq_restore
//
//  Created by Stefan Reitshamer on 8/19/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "ArqRepo_Verifier.h"
#import "ArqPackSet.h"

@implementation ArqRepo (Verifier)
- (NSString *)blobsPackSetName {
    return [blobsPackSet packSetName];
}
- (BOOL)packSHA1:(NSString **)packSHA1 forPackedBlobSHA1:(NSString *)sha1 error:(NSError **)error {
    return [blobsPackSet packSHA1:packSHA1 forPackedSHA1:sha1 error:error];
}
@end
