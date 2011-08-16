/*
 Copyright (c) 2009-2011, Stefan Reitshamer http://www.haystacksoftware.com
 
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

#import <openssl/evp.h>

#import "NSData-Encrypt.h"
#import "DataInputStream.h"
#import "EncryptedInputStream.h"
#import "DecryptedInputStream.h"

@implementation NSData (Encrypt)
- (NSData *)encryptWithCryptoKey:(CryptoKey *)theCryptoKey error:(NSError **)error {
    DataInputStream *dis = [[DataInputStream alloc] initWithData:self];
    EncryptedInputStream *encrypted = [[EncryptedInputStream alloc] initWithInputStream:dis cryptoKey:theCryptoKey error:error];
    [dis release];
    if (encrypted == nil) {
        return nil;
    }
    NSData *ret = [encrypted slurp:error];
    [encrypted release];
    return ret;
}
- (NSData *)decryptWithCryptoKey:(CryptoKey *)theCryptoKey error:(NSError **)error {
    DataInputStream *dis = [[DataInputStream alloc] initWithData:self];
    DecryptedInputStream *decrypted = [[DecryptedInputStream alloc] initWithInputStream:dis cryptoKey:theCryptoKey error:error];
    [dis release];
    if (decrypted == nil) {
        return nil;
    }
    NSData *ret = [decrypted slurp:error];
    [decrypted release];
    return ret;
}
@end
