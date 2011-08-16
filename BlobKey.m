//
//  BlobKey.m
//  Arq
//
//  Created by Stefan Reitshamer on 6/27/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "BlobKey.h"


@implementation BlobKey
- (id)initWithSHA1:(NSString *)theSHA1 stretchEncryptionKey:(BOOL)isStretchedKey {
    if (self = [super init]) {
        sha1 = [theSHA1 retain];
        stretchEncryptionKey = isStretchedKey;
    }
    return self;
}
- (void)dealloc {
    [sha1 release];
    [super dealloc];
}

- (NSString *)sha1 {
    return sha1;
}
- (BOOL)stretchEncryptionKey {
    return stretchEncryptionKey;
}


#pragma mark NSCopying
- (id)copyWithZone:(NSZone *)zone {
    return [[BlobKey alloc] initWithSHA1:sha1 stretchEncryptionKey:stretchEncryptionKey];
}


#pragma mark NSObject
- (NSString *)description {
    return [NSString stringWithFormat:@"<BlobKey %@,stretchedkey=%@>", sha1, (stretchEncryptionKey ? @"YES" : @"NO")];
}
- (BOOL)isEqual:(id)anObject {
    if (![anObject isKindOfClass:[BlobKey class]]) {
        return NO;
    }
    BlobKey *other = (BlobKey *)anObject;
    return [[other sha1] isEqualToString:sha1] && [other stretchEncryptionKey] == stretchEncryptionKey;
}
- (NSUInteger)hash {
    return [sha1 hash] + (stretchEncryptionKey ? 1 : 0);
}
@end
