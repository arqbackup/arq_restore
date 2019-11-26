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



@class BlobKey;
@class Target;
@protocol TargetConnectionDelegate;
@protocol ObjectEncryptorImpl;


@interface ObjectEncryptor : NSObject {
    Target *target;
    NSString *computerUUID;
    NSData *customV1Salt;
    id <TargetConnectionDelegate> targetConnectionDelegate;
    id <ObjectEncryptorImpl> impl;
    int encryptionVersion;
}

+ (NSString *)errorDomain;


- (id)initWithTarget:(Target *)theTarget
        computerUUID:(NSString *)theComputerUUID
  encryptionPassword:(NSString *)theEncryptionPassword
targetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD
               error:(NSError **)error;

- (id)initWithTarget:(Target *)theTarget
        computerUUID:(NSString *)theComputerUUID
  encryptionPassword:(NSString *)theEncryptionPassword
        customV1Salt:(NSData *)theCustomV1Salt
targetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD
               error:(NSError **)error;

- (int)encryptionVersion;

//- (NSNumber *)datFileExistsAtTarget:(NSError **)error;
- (BOOL)ensureDatFileExistsAtTargetWithEncryptionPassword:(NSString *)theEncryptionPassword targetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD error:(NSError **)error;

- (NSData *)encryptV1Data:(NSData *)theData error:(NSError **)error;
- (NSString *)sha1HashForV2Data:(NSData *)theData;
- (NSData *)v2EncryptedObjectFromData:(NSData *)theData masterIV:(NSData *)theMasterIV dataIVAndSymmetricKey:(NSData *)theDataIVAndSymmetricKey error:(NSError **)error;

//- (NSData *)encryptedObjectForData:(NSData *)theData sha1Hash:(NSString *)theSHA1 error:(NSError **)error;
//- (NSData *)encryptedObjectForData:(NSData *)theData blobKey:(BlobKey *)theBlobKey sha1Hash:(NSString *)theSHA1 error:(NSError **)error;

- (NSData *)decryptedDataForObject:(NSData *)theObject error:(NSError **)error;
- (NSData *)decryptedDataForObject:(NSData *)theObject blobKey:(BlobKey *)theBlobKey error:(NSError **)error;

- (BOOL)masterIV:(NSData **)theMasterIV dataIVAndSymmetricKey:(NSData **)theDataIVAndSymmetricKey fromEncryptedObjectHeader:(NSData *)theHeader error:(NSError **)error;
@end
