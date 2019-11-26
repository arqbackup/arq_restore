/*
 Copyright (c) 2009-2017, Haystack Software LLC https://www.arqbackup.com
 
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




@protocol S3AuthorizationProvider;
@protocol DataTransferDelegate;
@protocol TargetConnectionDelegate;


@interface S3Request : NSObject {
    NSString *method;
    NSURL *url;
    id <S3AuthorizationProvider> sap;
    id <DataTransferDelegate> dataTransferDelegate;
    NSData *requestBody;
    NSMutableDictionary *extraRequestHeaders;
    unsigned long long bytesUploaded;
    int httpResponseCode;
    NSMutableDictionary *responseHeaders;
}
- (id)initWithMethod:(NSString *)theMethod endpoint:(NSURL *)theEndpoint path:(NSString *)thePath queryString:(NSString *)theQueryString authorizationProvider:(id <S3AuthorizationProvider>)theSAP error:(NSError **)error;
- (id)initWithMethod:(NSString *)theMethod endpoint:(NSURL *)theEndpoint path:(NSString *)thePath queryString:(NSString *)theQueryString authorizationProvider:(id <S3AuthorizationProvider>)theSAP dataTransferDelegate:(id <DataTransferDelegate>)theDelegate error:(NSError **)error;
- (void)setRequestBody:(NSData *)theRequestBody;
- (void)setRequestHeader:(NSString *)value forKey:(NSString *)key;
- (int)httpResponseCode;
- (NSArray *)responseHeaderKeys;
- (NSString *)responseHeaderForKey:(NSString *)theKey;
- (NSData *)dataWithTargetConnectionDelegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error;
@end
