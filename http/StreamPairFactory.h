//
//  StreamPairFactory.h
//  CFN
//
//  Created by Stefan Reitshamer on 2/25/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
@protocol StreamPair;

@interface StreamPairFactory : NSObject {
    NSTimeInterval maxStreamPairLifetime;
    NSLock *lock;
    NSMutableDictionary *threadMap;
    
}
+ (StreamPairFactory *)theFactory;
- (void)setMaxStreamPairLifetime:(NSTimeInterval)theMaxLifetime;
- (id <StreamPair>)newStreamPairToHost:(NSString *)theHost useSSL:(BOOL)isUseSSL error:(NSError **)error;
- (void)clear;
@end
