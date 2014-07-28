//
//  ArqRestoreCommand.h
//  arq_restore
//
//  Created by Stefan Reitshamer on 7/25/14.
//
//

#import "S3RestorerDelegate.h"
#import "S3GlacierRestorerDelegate.h"
#import "GlacierRestorerDelegate.h"
@class Target;


@interface ArqRestoreCommand : NSObject <S3RestorerDelegate, S3GlacierRestorerDelegate, GlacierRestorerDelegate> {
    Target *target;
    unsigned long long maxRequested;
    unsigned long long maxTransfer;
}

- (NSString *)errorDomain;
- (BOOL)executeWithArgc:(int)argc argv:(const char **)argv error:(NSError **)error;
@end
