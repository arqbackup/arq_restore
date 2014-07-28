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


#import "GoogleDriveRequest.h"
#import "GoogleDrive.h"
#import "HTTPConnection.h"
#import "HTTPConnectionFactory.h"
#import "GoogleDriveErrorResult.h"
#import "TargetConnection.h"
#import "NSDictionary_HTTP.h"
#import "NSString+SBJSON.h"


#define INITIAL_RETRY_SLEEP (0.5)
#define RETRY_SLEEP_GROWTH_FACTOR (1.5)
#define MAX_RETRY_SLEEP (5.0)

static NSString *const kGoogleClientIDKey = @"INSERTHERE";
static NSString *const kGoogleClientSecretKey = @"INSERTHERE";


@implementation GoogleDriveRequest
- (id)initWithEmailAddress:(NSString *)theEmailAddress method:(NSString *)theMethod path:(NSString *)thePath queryString:(NSString *)theQueryString refreshToken:(NSString *)theRefreshToken googleDriveDelegate:(id<GoogleDriveDelegate>)theGoogleDriveDelegate dataTransferDelegate:(id<DataTransferDelegate>)theDelegate error:(NSError **)error {
    if (theQueryString != nil) {
        if ([theQueryString hasPrefix:@"?"]) {
            SETNSERROR([GoogleDrive errorDomain], -1, @"query string may not begin with a ?");
            [self release];
            return nil;
        }
        thePath = [[thePath stringByAppendingString:@"?"] stringByAppendingString:theQueryString];
    }
    if (![thePath hasPrefix:@"/upload/drive/v2"] && ![thePath hasPrefix:@"/drive/v2"]) {
        SETNSERROR([GoogleDrive errorDomain], -1, @"path must begin with /upload/drive/v2 or /drive/v2");
        [self release];
        return nil;
    }
    NSString *urlString = [NSString stringWithFormat:@"https://www.googleapis.com%@", thePath];
    NSURL *theURL = [[[NSURL alloc] initWithString:urlString] autorelease];
    if (theURL == nil) {
        SETNSERROR([GoogleDrive errorDomain], -1, @"invalid URL: %@", urlString);
        [self release];
        return nil;
    }
    return [self initWithEmailAddress:theEmailAddress method:theMethod url:theURL refreshToken:theRefreshToken googleDriveDelegate:theGoogleDriveDelegate dataTransferDelegate:theDelegate error:error];
}
- (id)initWithGetURL:(NSURL *)theURL refreshToken:(NSString *)theRefreshToken googleDriveDelegate:(id<GoogleDriveDelegate>)theGoogleDriveDelegate dataTransferDelegate:(id<DataTransferDelegate>)theDelegate error:(NSError **)error {
    return [self initWithEmailAddress:nil method:@"GET" url:theURL refreshToken:theRefreshToken googleDriveDelegate:theGoogleDriveDelegate dataTransferDelegate:theDelegate error:error];
}

- (id)initWithEmailAddress:(NSString *)theEmailAddress method:(NSString *)theMethod url:(NSURL *)theURL refreshToken:(NSString *)theRefreshToken googleDriveDelegate:(id<GoogleDriveDelegate>)theGoogleDriveDelegate dataTransferDelegate:(id<DataTransferDelegate>)theDelegate error:(NSError **)error {
    if (self = [super init]) {
        emailAddress = [theEmailAddress retain];
        method = [theMethod retain];
        url = [theURL retain];
        refreshToken = [theRefreshToken retain];
        googleDriveDelegate = theGoogleDriveDelegate;
        dataTransferDelegate = theDelegate;
        extraRequestHeaders = [[NSMutableDictionary alloc] init];
        responseHeaders = [[NSMutableDictionary alloc] init];
    }
    return self;
}
- (void)dealloc {
    [emailAddress release];
    [method release];
    [url release];
    [requestBody release];
    [extraRequestHeaders release];
    [responseHeaders release];
    [super dealloc];
}

- (void)setRequestBody:(NSData *)theRequestBody {
    [theRequestBody retain];
    [requestBody release];
    requestBody = theRequestBody;
}
- (void)setRequestHeader:(NSString *)value forKey:(NSString *)key {
    [extraRequestHeaders setObject:value forKey:key];
}
- (int)httpResponseCode {
    return httpResponseCode;
}
- (NSString *)responseHeaderForKey:(NSString *)theKey {
    return [responseHeaders objectForKey:theKey];
}
- (NSData *)dataWithTargetConnectionDelegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    NSAutoreleasePool *pool = nil;
    NSTimeInterval sleepTime = INITIAL_RETRY_SLEEP;
    NSData *responseData = nil;
    NSError *myError = nil;
    for (;;) {
        [pool drain];
        pool = [[NSAutoreleasePool alloc] init];
        BOOL needRetry = NO;
        BOOL needSleep = NO;
        myError = nil;
        responseData = [self dataOnce:&myError];
        if (responseData != nil) {
            break;
        }
        
        HSLogDebug(@"GoogleDriveRequest dataOnce failed; %@", myError);
        
        if ([myError isErrorWithDomain:[GoogleDrive errorDomain] code:ERROR_NOT_FOUND]) {
            break;
        }

        if ([myError isTransientError]) {
            needRetry = YES;
            needSleep = YES;
        }

        BOOL refreshedToken = NO;
        if ([myError isErrorWithDomain:[GoogleDrive errorDomain] code:401]) {
            NSString *accessToken = [self requestAccessToken:&myError];
            if (accessToken == nil) {
                HSLogError(@"failed to get new access token: %@", myError);
                break;
            }
            [googleDriveDelegate googleDriveDidChangeAccessToken:accessToken forRefreshToken:refreshToken];
            needRetry = YES;
            refreshedToken = YES;
        }
        
        if (!refreshedToken && (!needRetry || ![theDelegate targetConnectionShouldRetryOnTransientError:&myError])) {
            HSLogError(@"%@ %@: %@", method, url, myError);
            break;
        }
        
        HSLogDetail(@"retrying %@: %@", method, myError);
        if (needSleep) {
            [NSThread sleepForTimeInterval:sleepTime];
            sleepTime *= RETRY_SLEEP_GROWTH_FACTOR;
            if (sleepTime > MAX_RETRY_SLEEP) {
                sleepTime = MAX_RETRY_SLEEP;
            }
        }
    }
    [responseData retain];
    if (responseData == nil) {
        [myError retain];
    }
    [pool drain];
    [responseData autorelease];
    if (responseData == nil) {
        [myError autorelease];
        SETERRORFROMMYERROR;
    }
    
    return responseData;
}


#pragma mark internal
- (NSData *)dataOnce:(NSError **)error {
    id <HTTPConnection> conn = [[[HTTPConnectionFactory theFactory] newHTTPConnectionToURL:url method:method dataTransferDelegate:dataTransferDelegate] autorelease];
    if (conn == nil) {
        return nil;
    }
    [conn setRequestHostHeader];
    [conn setRFC822DateRequestHeader];
    if (requestBody != nil) {
        [conn setRequestHeader:[NSString stringWithFormat:@"%lu", (unsigned long)[requestBody length]] forKey:@"Content-Length"];
    }
    for (NSString *headerKey in [extraRequestHeaders allKeys]) {
        [conn setRequestHeader:[extraRequestHeaders objectForKey:headerKey] forKey:headerKey];
    }
    NSString *accessToken = [googleDriveDelegate googleDriveAccessTokenForRefreshToken:refreshToken];
    if (accessToken == nil) {
        accessToken = [self requestAccessToken:error];
        if (accessToken == nil) {
            return nil;
        }
        [googleDriveDelegate googleDriveDidChangeAccessToken:accessToken forRefreshToken:refreshToken];
    }
    [conn setRequestHeader:[NSString stringWithFormat:@"Bearer %@", accessToken] forKey:@"Authorization"];
    
    bytesUploaded = 0;
    
    HSLogDebug(@"%@ %@", method, url);
    
    [conn setRequestHeader:[NSString stringWithFormat:@"%lu", (unsigned long)[requestBody length]] forKey:@"Content-Length"];
    NSData *response = [conn executeRequestWithBody:requestBody error:error];
    if (response == nil) {
        return nil;
    }
    
    [responseHeaders setDictionary:[conn responseHeaders]];
    
    httpResponseCode = [conn responseCode];
    if (httpResponseCode >= 200 && httpResponseCode <= 299) {
        HSLogDebug(@"HTTP %d; returning response length=%ld", httpResponseCode, (long)[response length]);
        return response;
    }
    
    HSLogDebug(@"http response body: %@", [[[NSString alloc] initWithBytes:[response bytes] length:[response length] encoding:NSUTF8StringEncoding] autorelease]);
//    if (httpResponseCode == HTTP_NOT_FOUND) {
//        HSLogDebug(@"http response body: %@", [[[NSString alloc] initWithBytes:[response bytes] length:[response length] encoding:NSUTF8StringEncoding] autorelease]);
//        S3ErrorResult *errorResult = [[[S3ErrorResult alloc] initWithAction:[NSString stringWithFormat:@"%@ %@", method, [url description]] data:response httpErrorCode:httpResponseCode] autorelease];
//        NSError *myError = [errorResult error];
//        NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithDictionary:[myError userInfo]];
//        [userInfo setObject:[NSString stringWithFormat:@"%@ not found", url] forKey:NSLocalizedDescriptionKey];
//        myError = [NSError errorWithDomain:[S3Service errorDomain] code:ERROR_NOT_FOUND userInfo:userInfo];
//        HSLogDebug(@"%@", myError);
//        SETERRORFROMMYERROR;
//        return nil;
//    }
//    if (httpResponseCode == HTTP_METHOD_NOT_ALLOWED) {
//        HSLogError(@"%@ 405 error", url);
//        SETNSERROR([S3Service errorDomain], ERROR_RRS_NOT_FOUND, @"%@ 405 error", url);
//    }
//    if (httpResponseCode == HTTP_MOVED_TEMPORARILY) {
//        NSString *location = [conn responseHeaderForKey:@"Location"];
//        NSDictionary *userInfo = [NSDictionary dictionaryWithObject:location forKey:@"location"];
//        NSError *myError = [NSError errorWithDomain:[S3Service errorDomain] code:ERROR_TEMPORARY_REDIRECT userInfo:userInfo];
//        if (error != NULL) {
//            *error = myError;
//        }
//        HSLogDebug(@"returning moved-temporarily error");
//        return nil;
//    }
    GoogleDriveErrorResult *errorResult = [[[GoogleDriveErrorResult alloc] initWithAction:[NSString stringWithFormat:@"%@ %@", method, [url description]] data:response contentType:[responseHeaders objectForKey:@"Content-Type"] httpErrorCode:httpResponseCode] autorelease];
    NSError *myError = [errorResult error];
    HSLogDebug(@"%@ error: %@", conn, myError);
    SETERRORFROMMYERROR;
    
    return nil;
}

- (NSString *)requestAccessToken:(NSError **)error {
    HSLogDebug(@"requesting access token");
    
    id <HTTPConnection> conn = [[[HTTPConnectionFactory theFactory] newHTTPConnectionToURL:[NSURL URLWithString:@"https://accounts.google.com/o/oauth2/token"] method:@"POST" dataTransferDelegate:nil] autorelease];
    if (conn == nil) {
        return nil;
    }
    [conn setRequestHostHeader];
    [conn setRFC822DateRequestHeader];
    
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    [params setObject:kGoogleClientIDKey forKey:@"client_id"];
    [params setObject:kGoogleClientSecretKey forKey:@"client_secret"];
    [params setObject:refreshToken forKey:@"refresh_token"];
    [params setObject:@"refresh_token" forKey:@"grant_type"];

    NSString *encodedParams = [params wwwFormURLEncodedString];
    NSData *response = [conn executeRequestWithBody:[encodedParams dataUsingEncoding:NSUTF8StringEncoding] error:error];
    if (response == nil) {
        return nil;
    }
    
    if ([conn responseCode] != 200) {
        if ([[conn responseHeaderForKey:@"Content-Type"] hasPrefix:@"application/json"]) {
            NSString *responseJSONString = [[[NSString alloc] initWithData:response encoding:NSUTF8StringEncoding] autorelease];
            HSLogDebug(@"response JSON: %@", responseJSONString);
            
            NSDictionary *responseJSON = [responseJSONString JSONValue:NULL];
            if ([[responseJSON objectForKey:@"error"] isEqualToString:@"invalid_grant"]) {
                // This Google Drive user has probably revoked our authorization.
                NSString *errorDescription = @"Arq Access to this Google Drive account was revoked";
                if (emailAddress != nil) {
                    errorDescription = [NSString stringWithFormat:@"Arq access to Google Drive account '%@' was revoked", emailAddress];
                }
                SETNSERROR([GoogleDrive errorDomain], ERROR_ACCESS_REVOKED, @"%@", errorDescription);
                return nil;
            }
        }
        
        SETNSERROR([GoogleDrive errorDomain], [conn responseCode], @"Google Drive refresh_token HTTP error %d", [conn responseCode]);
        return nil;
    }
    
    NSString *responseString = [[[NSString alloc] initWithData:response encoding:NSUTF8StringEncoding] autorelease];
    NSDictionary *responseJSON = [responseString JSONValue:error];
    if (responseJSON == nil) {
        return nil;
    }
    NSString *accessToken = [responseJSON objectForKey:@"access_token"];
    
    HSLogDebug(@"accessToken expires in %@", [responseJSON objectForKey:@"expires_in"]);
    
    return accessToken;
}
@end
