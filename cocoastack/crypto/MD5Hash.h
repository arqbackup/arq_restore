//
//  MD5Hash.h
//  Arq
//
//  Created by Stefan Reitshamer on 1/1/14.
//  Copyright (c) 2014 Stefan Reitshamer. All rights reserved.
//


@interface MD5Hash : NSObject
+ (NSString *)hashDataBase64Encode:(NSData *)theData;
@end
