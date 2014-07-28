//
//  GoogleDriveErrorResult.h
//  Arq
//
//  Created by Stefan Reitshamer on 7/17/14.
//  Copyright (c) 2014 Stefan Reitshamer. All rights reserved.
//


@interface GoogleDriveErrorResult : NSObject {
    NSError *myError;
}
- (id)initWithAction:(NSString *)theAction data:(NSData *)theData contentType:(NSString *)theContentType httpErrorCode:(int)theHTTPStatusCode;

- (NSError *)error;
@end
