//
//  XAttrSet.h
//  Backup
//
//  Created by Stefan Reitshamer on 4/27/09.
//  Copyright 2009 PhotoMinds LLC. All rights reserved.
//


#import "BufferedInputStream.h"

@interface XAttrSet : NSObject {
    NSMutableDictionary *xattrs;
    NSString *path;
}
- (id)initWithPath:(NSString *)thePath error:(NSError **)error;
- (id)initWithBufferedInputStream:(BufferedInputStream *)is error:(NSError **)error;
- (NSData *)toData;
- (NSUInteger)count;
- (unsigned long long)dataLength;
- (NSArray *)names;
- (BOOL)applyToFile:(NSString *)path error:(NSError **)error;
@end
