//
//  CommitFailedFile.m
//  Arq
//
//  Created by Stefan Reitshamer on 2/22/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "CommitFailedFile.h"
#import "StringIO.h"
#import "BufferedInputStream.h"

@implementation CommitFailedFile
- (id)initWithPath:(NSString *)thePath errorMessage:(NSString *)theErrorMessage {
    if (self = [super init]) {
        path = [thePath copy];
        errorMessage = [theErrorMessage copy];
    }
    return self;
}
- (id)initWithInputStream:(BufferedInputStream *)is error:(NSError **)error {
    if (self = [super init]) {
        if (![StringIO read:&path from:is error:error]
            || ![StringIO read:&errorMessage from:is error:error]) {
            [self release];
            return nil;
        }
        [path retain];
        [errorMessage retain];
    }
    return self;
}
- (void)dealloc {
    [path release];
    [errorMessage release];
    [super dealloc];
}
- (NSString *)path {
    return [[path retain] autorelease];
}
- (NSString *)errorMessage {
    return [[errorMessage retain] autorelease];
}
- (void)writeTo:(NSMutableData *)data {
    [StringIO write:path to:data];
    [StringIO write:errorMessage to:data];
}
- (BOOL)isEqualToCommitFailedFile:(CommitFailedFile *)cff {
    return [[cff path] isEqualToString:path] && [[cff errorMessage] isEqualToString:errorMessage];
}

#pragma mark NSObject
- (BOOL)isEqual:(id)other {
    if (other == self) {
        return YES;
    }
    if (other == nil || ![other isKindOfClass:[self class]]) {
        return NO;
    }
    return [self isEqualToCommitFailedFile:other];
}
@end
