//
//  UserLibrary.m
//  Backup
//
//  Created by Stefan Reitshamer on 8/18/09.
//  Copyright 2009 PhotoMinds LLC. All rights reserved.
//

#import "UserLibrary_Arq.h"


@implementation UserLibrary (Arq)
+ (NSString *)arqUserLibraryPath {
    return [[NSHomeDirectory() stringByAppendingPathComponent:@"Library"] stringByAppendingPathComponent:@"Arq"];
}
+ (NSString *)arqCachePath {
    return [NSString stringWithFormat:@"%@/Cache.noindex", [UserLibrary arqUserLibraryPath]];
}
@end
