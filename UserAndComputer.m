//
//  UserAndComputer.m
//  Arq
//
//  Created by Stefan Reitshamer on 7/9/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "UserAndComputer.h"
#import "DictNode.h"

@implementation UserAndComputer
- (id)initWithXMLData:(NSData *)theXMLData error:(NSError **)error {
    if (self = [super init]) {
        DictNode *plist = [DictNode dictNodeWithXMLData:theXMLData error:error];
        if (plist == nil) {
            [self release];
            return nil;
        }
        userName = [[[plist stringNodeForKey:@"userName"] stringValue] copy];
        computerName = [[[plist stringNodeForKey:@"computerName"] stringValue] copy];
    }
    return self;
}
- (void)dealloc {
    [userName release];
    [computerName release];
    [super dealloc];
}
- (NSString *)userName {
    return userName;
}
- (NSString *)computerName {
    return computerName;
}
- (NSData *)toXMLData {
    DictNode *plist = [[[DictNode alloc] init] autorelease];
    [plist putString:userName forKey:@"userName"];
    [plist putString:computerName forKey:@"computerName"];
    return [plist XMLData];
}

#pragma mark NSObject
- (NSString *)description {
    return [NSString stringWithFormat:@"<UserAndComputer: userName=%@ computerName=%@>", userName, computerName];
}
@end
