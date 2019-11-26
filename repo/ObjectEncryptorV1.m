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



#import "ObjectEncryptorV1.h"
#import "ArqSalt.h"
#import "Target.h"
#import "CryptoKey.h"
#import "BlobKey.h"
#import "SHA1Hash.h"
#import "EncryptionDatFile.h"

#define ENCRYPTION_VERSION (1)


@implementation ObjectEncryptorV1
- (id)initWithTarget:(Target *)theTarget
        computerUUID:(NSString *)theComputerUUID
           masterKey:(NSData *)theMasterKey
targetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD
               error:(NSError **)error {
    ArqSalt *arqSalt = [[[ArqSalt alloc] initWithTarget:theTarget computerUUID:theComputerUUID error:error] autorelease];
    if (arqSalt == nil) {
        [self release];
        return nil;
    }
    NSData *saltData = [arqSalt saltDataWithTargetConnectionDelegate:theTCD error:error];
    if (saltData == nil) {
        [self release];
        return nil;
    }
    return [self initWithTarget:theTarget computerUUID:theComputerUUID masterKey:theMasterKey salt:saltData error:error];
}

- (id)initWithTarget:(Target *)theTarget
        computerUUID:(NSString *)theComputerUUID
           masterKey:(NSData *)theMasterKey
                salt:(NSData *)theSalt
               error:(NSError **)error {
    if (self = [super init]) {
        target = [theTarget retain];
        computerUUID = [theComputerUUID retain];
        
        NSString *theMasterPassword = [[[NSString alloc] initWithData:theMasterKey encoding:NSUTF8StringEncoding] autorelease];
        
        cryptoKey = [[CryptoKey alloc] initLegacyWithPassword:theMasterPassword error:error];
        if (cryptoKey == nil) {
            [self release];
            return nil;
        }
        stretchedCryptoKey = [[CryptoKey alloc] initWithPassword:theMasterPassword salt:theSalt error:error];
        if (stretchedCryptoKey == nil) {
            [self release];
            return nil;
        }

    }
    return self;
}
- (void)dealloc {
    [target release];
    [computerUUID release];
    [cryptoKey release];
    [stretchedCryptoKey release];
    [super dealloc];
}


#pragma ObjectEncryptorImpl
- (BOOL)ensureDatFileExistsAtTargetWithEncryptionPassword:(NSString *)theEncryptionPassword targetConnectionDelegate:(id<TargetConnectionDelegate>)theTCD error:(NSError **)error {
    ArqSalt *arqSalt = [[[ArqSalt alloc] initWithTarget:target computerUUID:computerUUID error:error] autorelease];
    if (arqSalt == nil) {
        return NO;
    }
    if (![arqSalt ensureSaltExistsAtTargetWithTargetConnectionDelegate:theTCD error:error]) {
        return NO;
    }

    NSError *myError = nil;
    EncryptionDatFile *encryptionDatFile = [[[EncryptionDatFile alloc] initFromTargetWithEncryptionPassword:theEncryptionPassword target:target computerUUID:computerUUID encryptionVersion:ENCRYPTION_VERSION targetConnectionDelegate:theTCD error:&myError] autorelease];
    if (encryptionDatFile == nil) {
        if ([myError code] != ERROR_NOT_FOUND) {
            SETERRORFROMMYERROR;
            return NO;
        }
        
        encryptionDatFile = [[[EncryptionDatFile alloc] initFromLocalCacheWithEncryptionPassword:theEncryptionPassword target:target computerUUID:computerUUID encryptionVersion:ENCRYPTION_VERSION error:&myError] autorelease];
        if (encryptionDatFile == nil) {
            if ([myError code] != ERROR_NOT_FOUND) {
                SETERRORFROMMYERROR;
                return NO;
            }
            
            // No encryptionv1.dat file, no problem. It means the user of v1 data never changed her password.
            
        } else {
            // Copy the encryptionv1.dat file from cache to the destination.
            if (![encryptionDatFile saveToTargetWithTargetConnectionDelegate:theTCD error:error]) {
                return NO;
            }
        }
    }
    
    return YES;
}
- (NSData *)encryptV1Data:(NSData *)theData error:(NSError **)error {
    return [stretchedCryptoKey encrypt:theData error:error];
}
- (NSString *)sha1HashForV2Data:(NSData *)theData {
    return nil;
}
- (NSData *)v2EncryptedObjectFromData:(NSData *)theData masterIV:(NSData *)theMasterIV dataIVAndSymmetricKey:(NSData *)theDataIVAndSymmetricKey error:(NSError **)error {
    SETNSERROR(@"ObjectEncryptorV1", -1, @"writeV2EncryptedObjectFromData not supported");
    return nil;
}
//
//- (NSString *)sha1HashForData:(NSData *)theData error:(NSError **)error {
//    // In V1 we hashed the encrypted data.
//    // We always got the same hash because we always used the same IV :-O
//    NSData *encryptedData = [stretchedCryptoKey encrypt:theData error:error];
//    if (encryptedData == nil) {
//        return nil;
//    }
//    return [SHA1Hash hashData:encryptedData];
//}
//- (NSData *)encryptedObjectForData:(NSData *)theData sha1Hash:(NSString *)theSHA1Hash error:(NSError **)error {
//    // In V1 we hashed the encrypted data.
//    // We always got the same hash because we always used the same IV :-O
//    return [stretchedCryptoKey encrypt:theData error:error];
//}
//- (NSData *)encryptedObjectForData:(NSData *)theData blobKey:(BlobKey *)theBlobKey sha1Hash:(NSString *)theSHA1Hash error:(NSError **)error {
//    CryptoKey *selectedCryptoKey = [theBlobKey stretchEncryptionKey] ? stretchedCryptoKey : cryptoKey;
//    return [selectedCryptoKey encrypt:theData error:error];
//}

- (NSData *)decryptedDataForObject:(NSData *)theObject error:(NSError **)error {
    return [stretchedCryptoKey decrypt:theObject error:error];
}
- (NSData *)decryptedDataForObject:(NSData *)theObject blobKey:(BlobKey *)theBlobKey error:(NSError **)error {
    CryptoKey *selectedCryptoKey = [theBlobKey stretchEncryptionKey] ? stretchedCryptoKey : cryptoKey;
    return [selectedCryptoKey decrypt:theObject error:error];
}
- (BOOL)masterIV:(NSData **)theMasterIV dataIVAndSymmetricKey:(NSData **)theDataIVAndSymmetricKey fromEncryptedObjectHeader:(NSData *)theHeader error:(NSError **)error {
    SETNSERROR(@"ObjectEncryptorV1", -1, @"masterIV:dataIVAndSymmetricKey:fromEncryptedObjectHeader:error: not supported");
    return NO;
}
@end
