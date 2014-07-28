//
//  ArqRestoreCommand.h
//  arq_restore
//
//  Created by Stefan Reitshamer on 7/25/14.
//
//

#import "S3RestorerDelegate.h"
@class Target;


@interface ArqRestoreCommand : NSObject <S3RestorerDelegate> {
    Target *target;
}

- (NSString *)errorDomain;
- (BOOL)executeWithArgc:(int)argc argv:(const char **)argv error:(NSError **)error;
@end
