/*
 Copyright (c) 2009-2014, Stefan Reitshamer http://www.haystacksoftware.com
 
 All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 
 * Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in the
 documentation and/or other materials provided with the distribution.
 
 * Neither the names of PhotoMinds LLC or Haystack Software, nor the names of
 their contributors may be used to endorse or promote products derived from
 this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
 TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */


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
