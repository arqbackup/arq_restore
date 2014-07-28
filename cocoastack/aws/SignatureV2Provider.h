//
//  SignatureV2Provider.h
//  Arq
//
//  Created by Stefan Reitshamer on 9/16/12.
//
//


@interface SignatureV2Provider : NSObject {
    NSData *secretKeyData;
}
- (id)initWithSecretKey:(NSString *)secret;
- (NSString *)signatureForHTTPMethod:(NSString *)theMethod url:(NSURL *)theURL;
@end
