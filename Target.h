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



@class DictNode;
@class BufferedInputStream;
@class BufferedOutputStream;
@class S3Service;
@class TargetConnection;


enum TargetType {
    kTargetAWS = 0,
    kTargetLocal = 12
};
typedef int TargetType;



/*
 * Example endpoints:
 * https://AKIAIYUK3N3TME6L4HFA@s3.amazonaws.com/arq-akiaiyuk3n3tme6l4hfa-us-east-1
 * sftp://stefan@filosync.reitshamer.com/home/stefan
 */

@interface Target : NSObject {
    NSString *uuid;
    NSString *nickname;
    NSURL *endpoint;
    int32_t awsRequestSignatureVersion;
    NSString *oAuth2ClientId;
    NSString *oAuth2RedirectURI;
    
    TargetType targetType;
}

- (id)initWithUUID:(NSString *)theUUID
          nickname:(NSString *)theNickname
          endpoint:(NSURL *)theEndpoint
awsRequestSignatureVersion:(int32_t)theAWSRequestSignatureVersion;

- (id)initWithPlist:(DictNode *)thePlist;

- (id)initWithBufferedInputStream:(BufferedInputStream *)theBIS error:(NSError **)error;

- (NSString *)errorDomain;

- (NSString *)targetUUID;
- (NSString *)nickname;
- (NSURL *)endpoint;
- (NSString *)endpointDisplayName;

- (int)awsRequestSignatureVersion;

- (NSString *)secret:(NSError **)error;
- (BOOL)setSecret:(NSString *)theSecret trustedAppPaths:(NSArray *)theTrustedAppPaths error:(NSError **)error;
- (BOOL)deleteSecret:(NSError **)error;

- (NSString *)passphrase:(NSError **)error;
- (BOOL)setPassphrase:(NSString *)theSecret trustedAppPaths:(NSArray *)theTrustedAppPaths error:(NSError **)error;
- (BOOL)deletePassphrase:(NSError **)error;

- (NSString *)oAuth2ClientId;
- (void)setOAuth2ClientId:(NSString *)value;

- (NSString *)oAuth2RedirectURI;
- (void)setOAuth2RedirectURI:(NSString *)value;

- (NSString *)oAuth2ClientSecret:(NSError **)error;
- (BOOL)setOAuth2ClientSecret:(NSString *)theSecret trustedAppPaths:(NSArray *)theTrustedAppPaths error:(NSError **)error;
- (BOOL)deleteOAuth2ClientSecret:(NSError **)error;

- (DictNode *)toPlist;

- (BOOL)writeTo:(BufferedOutputStream *)theBOS error:(NSError **)error;
- (void)writeTo:(NSData *)data;

- (S3Service *)s3:(NSError **)error;

- (TargetConnection *)newConnection:(NSError **)error;

- (TargetType)targetType;
- (BOOL)canAccessFilesByPath;
@end
