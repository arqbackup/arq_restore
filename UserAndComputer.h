//
//  UserAndComputer.h
//  Arq
//
//  Created by Stefan Reitshamer on 7/9/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface UserAndComputer : NSObject {
    NSString *userName;
    NSString *computerName;
}
- (id)init;
- (id)initWithXMLData:(NSData *)theXMLData error:(NSError **)error;
- (id)initWithUserName:(NSString *)theUserName computerName:(NSString *)theComputerName;
- (NSString *)userName;
- (NSString *)computerName;
- (NSData *)toXMLData;
@end
