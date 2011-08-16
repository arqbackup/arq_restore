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

#import "Blob.h"
#import "DataInputStreamFactory.h"
#import "NSData-Base64Extensions.h"
#import "EncryptedInputStreamFactory.h"
#import "NSData-Encrypt.h"

@implementation Blob
- (id)initWithInputStreamFactory:(id <InputStreamFactory>)theFactory mimeType:(NSString *)theMimeType downloadName:(NSString *)theDownloadName {
    if (self = [super init]) {
        mimeType = [theMimeType copy];
        downloadName = [theDownloadName copy];
        inputStreamFactory = [theFactory retain];
    }
    return self;
}
- (id)initWithData:(NSData *)theData mimeType:(NSString *)theMimeType downloadName:(NSString *)theDownloadName dataDescription:(NSString *)theDataDescription {
    if (self = [super init]) {
        mimeType = [theMimeType copy];
        downloadName = [theDownloadName copy];
        inputStreamFactory = [[DataInputStreamFactory alloc] initWithData:theData dataDescription:theDataDescription];
    }
    return self;
}
- (void)dealloc {
    [mimeType release];
    [downloadName release];
    [inputStreamFactory release];
	[super dealloc];
}
- (NSString *)mimeType {
    return mimeType;
}
- (NSString *)downloadName {
    return downloadName;
}
- (id <InputStreamFactory>)inputStreamFactory {
    return inputStreamFactory;
}
- (NSData *)slurp:(NSError **)error {
    id <InputStream> is = [inputStreamFactory newInputStream];
    NSData *data = [is slurp:error];
    [is release];
    return data;
}
- (Blob *)encryptedBlobWithCryptoKey:(CryptoKey *)theCryptoKey error:(NSError **)error {
    NSString *base64EncryptedDownloadName = nil;
    if (downloadName != nil) {
        NSData *encryptedDownloadNameData = [[downloadName dataUsingEncoding:NSUTF8StringEncoding] encryptWithCryptoKey:theCryptoKey error:error];
        if (encryptedDownloadNameData == nil) {
            return nil;
        }
        base64EncryptedDownloadName = [encryptedDownloadNameData encodeBase64];
    }
    EncryptedInputStreamFactory *eisf = [[EncryptedInputStreamFactory alloc] initWithCryptoKey:theCryptoKey underlyingFactory:inputStreamFactory];
    NSString *dataDescription = [eisf description];
    id <InputStream> is = [eisf newInputStream];
    NSData *encryptedData = [is slurp:error];
    [is release];
    [eisf release];
    if (encryptedData == nil) {
        return nil;
    }
    Blob *blob = [[[Blob alloc] initWithData:encryptedData mimeType:mimeType downloadName:base64EncryptedDownloadName dataDescription:dataDescription] autorelease];
    return blob;
}

#pragma mark NSObject
- (NSString *)description {
    return [NSString stringWithFormat:@"<Blob: %@>", [inputStreamFactory description]];
}
@end
