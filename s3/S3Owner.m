//
//  S3Owner.m
//  Backup
//
//  Created by Stefan Reitshamer on 4/12/09.
//  Copyright 2009 PhotoMinds LLC. All rights reserved.
//

#import "S3Owner.h"


@implementation S3Owner
- (id)initWithDisplayName:(NSString *)dn idString:(NSString *)ids {
	if (self = [super init]) {
		displayName = [dn copy];
		idString = [ids copy];
	}
	return self;
}
- (NSString *)displayName {
	return displayName;
}
- (NSString *)idString {
	return idString;
}
@end
