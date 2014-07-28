//
//  NSErrorIO.h
//  Arq
//
//  Created by Stefan Reitshamer on 6/5/13.
//  Copyright (c) 2013 Stefan Reitshamer. All rights reserved.
//

@class BufferedInputStream;
@class BufferedOutputStream;


@interface NSErrorIO : NSObject {
    
}
+ (BOOL)write:(NSError *)theError to:(BufferedOutputStream *)theBOS error:(NSError **)error;
+ (BOOL)read:(NSError **)theError from:(BufferedInputStream *)theBIS error:(NSError **)error;
@end
