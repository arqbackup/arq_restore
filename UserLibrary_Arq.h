//
//  UserLibrary.h
//  Backup
//
//  Created by Stefan Reitshamer on 8/18/09.
//  Copyright 2009 PhotoMinds LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "UserLibrary.h"

@interface UserLibrary (Arq)
+ (NSString *)arqUserLibraryPath;
+ (NSString *)arqCachePath;
@end
