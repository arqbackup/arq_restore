//
//  GoogleDriveRequest.h
//  Arq
//
//  Created by Stefan Reitshamer on 7/17/14.
//  Copyright (c) 2014 Stefan Reitshamer. All rights reserved.
//

@class GoogleDriveAuthorizationProvider;
@class Target;
@protocol TargetConnectionDelegate;
@protocol DataTransferDelegate;
@protocol GoogleDriveDelegate;


@interface GoogleDriveRequest : NSObject {
    NSString *emailAddress;
    NSString *method;
    NSURL *url;
    NSString *refreshToken;
    id <GoogleDriveDelegate> googleDriveDelegate;
    
    id <DataTransferDelegate> dataTransferDelegate;
    NSData *requestBody;
    NSMutableDictionary *extraRequestHeaders;
    unsigned long long bytesUploaded;
    int httpResponseCode;
    NSMutableDictionary *responseHeaders;
}

- (id)initWithEmailAddress:(NSString *)theEmailAddress
                    method:(NSString *)theMethod
                      path:(NSString *)thePath
               queryString:(NSString *)theQueryString
              refreshToken:(NSString *)theRefreshToken
       googleDriveDelegate:(id <GoogleDriveDelegate>)theGoogleDriveDelegate
      dataTransferDelegate:(id <DataTransferDelegate>)theDelegate
                     error:(NSError **)error;

- (id)initWithGetURL:(NSURL *)theURL
        refreshToken:(NSString *)theRefreshToken
 googleDriveDelegate:(id <GoogleDriveDelegate>)theGoogleDriveDelegate
dataTransferDelegate:(id <DataTransferDelegate>)theDelegate
               error:(NSError **)error;


- (void)setRequestBody:(NSData *)theRequestBody;
- (void)setRequestHeader:(NSString *)value forKey:(NSString *)key;
- (int)httpResponseCode;
- (NSString *)responseHeaderForKey:(NSString *)theKey;
- (NSData *)dataWithTargetConnectionDelegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error;
@end
