//
//  PackId.m
//  Arq
//
//  Created by Stefan Reitshamer on 12/30/13.
//  Copyright (c) 2013 Stefan Reitshamer. All rights reserved.
//

#import "PackId.h"

@implementation PackId
- (id)initWithPackSetName:(NSString *)thePackSetName packSHA1:(NSString *)thePackSHA1 {
    if (self = [super init]) {
        packSetName = [thePackSetName retain];
        packSHA1 = [thePackSHA1 retain];
    }
    return self;
}
- (void)dealloc {
    [packSetName release];
    [packSHA1 release];
    [super dealloc];
}

- (NSString *)packSetName {
    return packSetName;
}
- (NSString *)packSHA1 {
    return packSHA1;
}


#pragma mark NSObject
- (NSString *)description {
    return [NSString stringWithFormat:@"<PackId: packset=%@,sha1=%@>", packSetName, packSHA1];
}
- (NSUInteger)hash {
    return [packSetName hash] + [packSHA1 hash];
}
- (BOOL)isEqual:(id)anObject {
    if (![anObject isKindOfClass:[PackId class]]) {
        return NO;
    }
    PackId *other = (PackId *)anObject;
    return [packSetName isEqualToString:[other packSetName]] && [packSHA1 isEqualToString:[other packSHA1]];
}
@end
