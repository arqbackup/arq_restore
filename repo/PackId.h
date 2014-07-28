//
//  PackId.h
//  Arq
//
//  Created by Stefan Reitshamer on 12/30/13.
//  Copyright (c) 2013 Stefan Reitshamer. All rights reserved.
//


@interface PackId : NSObject {
    NSString *packSetName;
    NSString *packSHA1;
}
- (id)initWithPackSetName:(NSString *)thePackSetName packSHA1:(NSString *)thePackSHA1;
- (NSString *)packSetName;
- (NSString *)packSHA1;
@end
