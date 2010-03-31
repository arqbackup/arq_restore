//
//  S3Owner.h
//  Backup
//
//  Created by Stefan Reitshamer on 4/12/09.
//  Copyright 2009 PhotoMinds LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface S3Owner : NSObject {
	NSString *displayName;
	NSString *idString;
}
- (id)initWithDisplayName:(NSString *)dn idString:(NSString *)ids;
- (NSString *)displayName;
- (NSString *)idString;
@end
