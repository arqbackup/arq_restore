//
//  AppKeychain.h
//  arq_restore
//
//  Created by Stefan Reitshamer on 8/19/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface AppKeychain : NSObject {
}
+ (NSString *)errorDomain;
+ (BOOL)accessKeyID:(NSString **)accessKeyID secretAccessKey:(NSString **)secret error:(NSError **)error;
+ (BOOL)encryptionKey:(NSString **)encryptionKey error:(NSError **)error;
@end
