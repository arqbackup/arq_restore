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




#import <CommonCrypto/CommonCryptor.h>
#import "ObjectEncryptor.h"
#import "ObjectEncryptorImpl.h"
#import "ObjectEncryptorV1.h"
#import "ObjectEncryptorV2.h"
#import "EncryptionDatFile.h"
#import "Target.h"


@implementation ObjectEncryptor
+ (NSString *)errorDomain {
    return @"ObjectEncryptorErrorDomain";
}


- (id)initWithTarget:(Target *)theTarget
        computerUUID:(NSString *)theComputerUUID
  encryptionPassword:(NSString *)theEncryptionPassword
targetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD
               error:(NSError **)error {
    return [self initWithTarget:theTarget computerUUID:theComputerUUID encryptionPassword:theEncryptionPassword customV1Salt:nil targetConnectionDelegate:theTCD error:error];
}

- (id)initWithTarget:(Target *)theTarget
        computerUUID:(NSString *)theComputerUUID
  encryptionPassword:(NSString *)theEncryptionPassword
        customV1Salt:(NSData *)theCustomV1Salt
targetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD
               error:(NSError **)error {
    if (theComputerUUID == nil) {
        SETNSERROR([ObjectEncryptor errorDomain], -1, @"no computerUUID given for ObjectEncryptor");
        return nil;
    }
    
    if (self = [super init]) {
        target = [theTarget retain];
        computerUUID = [theComputerUUID retain];
        customV1Salt = [theCustomV1Salt retain];
        targetConnectionDelegate = theTCD;
        
        if (![self initializeWithEncryptionPassword:theEncryptionPassword error:error]) {
            [self release];
            return nil;
        }
    }
    return self;
}
- (void)dealloc {
    [target release];
    [computerUUID release];
    [super dealloc];
}

- (int)encryptionVersion {
    return encryptionVersion;
}

- (BOOL)ensureDatFileExistsAtTargetWithEncryptionPassword:(NSString *)theEncryptionPassword targetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD error:(NSError **)error {
    return [impl ensureDatFileExistsAtTargetWithEncryptionPassword:theEncryptionPassword targetConnectionDelegate:theTCD error:error];
}

- (NSData *)encryptV1Data:(NSData *)theData error:(NSError **)error {
    return [impl encryptV1Data:theData error:error];
}
- (NSString *)sha1HashForV2Data:(NSData *)theData {
    return [impl sha1HashForV2Data:theData];
}
- (NSData *)v2EncryptedObjectFromData:(NSData *)theData masterIV:(NSData *)theMasterIV dataIVAndSymmetricKey:(NSData *)theDataIVAndSymmetricKey error:(NSError **)error {
    return [impl v2EncryptedObjectFromData:theData masterIV:theMasterIV dataIVAndSymmetricKey:theDataIVAndSymmetricKey error:error];
}

- (NSData *)decryptedDataForObject:(NSData *)theObject error:(NSError **)error {
    return [impl decryptedDataForObject:theObject error:error];
}
- (NSData *)decryptedDataForObject:(NSData *)theObject blobKey:(BlobKey *)theBlobKey error:(NSError **)error {
    return [impl decryptedDataForObject:theObject blobKey:theBlobKey error:error];
}

- (BOOL)masterIV:(NSData **)theMasterIV dataIVAndSymmetricKey:(NSData **)theDataIVAndSymmetricKey fromEncryptedObjectHeader:(NSData *)theHeader error:(NSError **)error {
    return [impl masterIV:theMasterIV dataIVAndSymmetricKey:theDataIVAndSymmetricKey fromEncryptedObjectHeader:theHeader error:error];
}


#pragma mark internal
- (BOOL)initializeWithEncryptionPassword:(NSString *)theEncryptionPassword error:(NSError **)error {
    encryptionVersion = 1;
    NSData *theMasterKeys = nil;
    NSError *myError = nil;
    EncryptionDatFile *datFile = [EncryptionDatFile encryptionDatFileForTarget:target
                                                                  computerUUID:computerUUID
                                                            encryptionPassword:theEncryptionPassword
                                                      targetConnectionDelegate:targetConnectionDelegate
                                                                         error:&myError];
    if (datFile == nil) {
        if ([myError code] != ERROR_NOT_FOUND) {
            SETERRORFROMMYERROR;
            return NO;
        }
        
        // There are no encryptionv1/2.dat files, so use the encryption password directly.
        theMasterKeys = [theEncryptionPassword dataUsingEncoding:NSUTF8StringEncoding];
    } else {
        encryptionVersion = [datFile encryptionVersion];
        theMasterKeys = [datFile masterKeys];
    }
    
    if (encryptionVersion == 1) {
        if (customV1Salt == nil) {
            impl = [[ObjectEncryptorV1 alloc] initWithTarget:target computerUUID:computerUUID masterKey:theMasterKeys targetConnectionDelegate:targetConnectionDelegate error:error];
        } else {
            // This is for bucket plists which were encrypted in V1 days using a hard-coded salt.
            impl = [[ObjectEncryptorV1 alloc] initWithTarget:target computerUUID:computerUUID masterKey:theMasterKeys salt:customV1Salt error:error];
        }
    } else {
        impl = [[ObjectEncryptorV2 alloc] initWithTarget:target computerUUID:computerUUID encryptionDatFile:datFile encryptionPassword:theEncryptionPassword error:error];
    }
    if (impl == nil) {
        return NO;
    }
    return YES;
}
@end
