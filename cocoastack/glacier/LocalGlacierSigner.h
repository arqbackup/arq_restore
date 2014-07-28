//
//  LocalGlacierSigner.h
//  Arq
//
//  Created by Stefan Reitshamer on 9/7/12.
//
//

#import "GlacierSigner.h"


@interface LocalGlacierSigner : NSObject <GlacierSigner> {
    NSString *secretKey;
}
- (id)initWithSecretKey:(NSString *)theSecretKey;
@end
