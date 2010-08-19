/*
 Copyright (c) 2009-2010, Stefan Reitshamer http://www.haystacksoftware.com
 
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

#import <Cocoa/Cocoa.h>
@class S3AuthorizationProvider;
@class ServerBlob;
@class Blob;

@interface S3Request : NSObject {
    NSString *method;
    NSString *path;
    NSString *s3BucketName;
    NSString *queryString;
    S3AuthorizationProvider *sap;
    BOOL withSSL;
    BOOL retryOnNetworkError;
    Blob *blob;
    uint64_t length;
    NSString *virtualHost;
    NSString *virtualPath;
    NSMutableDictionary *extraHeaders;
    id delegate;
    unsigned long long bytesUploaded;
}
- (id)initWithMethod:(NSString *)theMethod path:(NSString *)thePath queryString:(NSString *)theQueryString authorizationProvider:(S3AuthorizationProvider *)theSAP useSSL:(BOOL)ssl retryOnNetworkError:(BOOL)retry;
- (void)setDelegate:(id)theDelegate;
- (void)setBlob:(Blob *)theBlob length:(uint64_t)theLength;
- (void)setHeader:(NSString *)value forKey:(NSString *)key;
- (ServerBlob *)newServerBlob:(NSError **)error;
@end

@interface NSObject (S3RequestDelegate)
- (BOOL)s3Request:(S3Request *)s3r willUploadBytes:(unsigned long long)theLength error:(NSError **)error;
- (void)s3Request:(S3Request *)s3r bytesFailedToUpload:(unsigned long long)theLength;
@end
