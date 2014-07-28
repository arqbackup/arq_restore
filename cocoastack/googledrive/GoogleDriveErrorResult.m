//
//  GoogleDriveErrorResult.m
//  Arq
//
//  Created by Stefan Reitshamer on 7/17/14.
//  Copyright (c) 2014 Stefan Reitshamer. All rights reserved.
//

#import "GoogleDriveErrorResult.h"
#import "GoogleDrive.h"
#import "NSString+SBJSON.h"


@implementation GoogleDriveErrorResult
- (id)initWithAction:(NSString *)theAction data:(NSData *)theData contentType:(NSString *)theContentType httpErrorCode:(int)theHTTPStatusCode {
    if (self = [super init]) {
        myError = [[self googleDriveErrorForAction:theAction data:theData contentType:theContentType httpErrorCode:theHTTPStatusCode] retain];
        if (myError == nil) {
            myError = [[NSError errorWithDomain:[GoogleDrive errorDomain] code:-1 description:[NSString stringWithFormat:@"%@: HTTP error %d", theAction, theHTTPStatusCode]] retain];
        }
    }
    return self;
}
- (void)dealloc {
    [myError release];
    [super dealloc];
}

- (NSError *)error {
    return myError;
}
    

#pragma mark internal
- (NSError *)googleDriveErrorForAction:(NSString *)theAction data:(NSData *)theData contentType:(NSString *)theContentType httpErrorCode:(int)theHTTPStatusCode {
    if ([theContentType hasPrefix:@"application/json"]) {
        NSString *jsonString = [[[NSString alloc] initWithData:theData encoding:NSUTF8StringEncoding] autorelease];
        HSLogDebug(@"google drive response json: %@", jsonString);
        NSError *theError = nil;
        NSDictionary *json = [jsonString JSONValue:&theError];
        if (json == nil) {
            HSLogError(@"failed to parse google drive response json: %@", theError);
            return nil;
        }
        NSDictionary *error = [json objectForKey:@"error"];
        NSNumber *errorCode = [error objectForKey:@"code"];
        NSString *errorMessage = [error objectForKey:@"message"];
        
        if (theHTTPStatusCode == 403) {
            errorCode = [NSNumber numberWithInt:ERROR_ACCESS_DENIED];
        } else if (theHTTPStatusCode == 404) {
            errorCode = [NSNumber numberWithInt:ERROR_NOT_FOUND];
        }
        
        NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                                  errorCode, @"errorCode",
                                  errorMessage, @"errorMessage",
                                  errorMessage, NSLocalizedDescriptionKey,
                                  nil];
        return [NSError errorWithDomain:[GoogleDrive errorDomain] code:[errorCode integerValue] userInfo:userInfo];
    }
    return nil;
}
@end
