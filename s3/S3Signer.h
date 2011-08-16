//
//  S3Signer.h
//  Arq
//
//  Created by Stefan Reitshamer on 12/30/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@protocol S3Signer <NSObject>
- (NSString *)sign:(NSString *)theString error:(NSError **)error;
@end
