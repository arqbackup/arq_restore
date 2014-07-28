//
//  SHA256Hash.h
//  Arq
//
//  Created by Stefan Reitshamer on 9/8/12.
//
//


@interface SHA256Hash : NSObject {
    
}
+ (NSData *)hashData:(NSData *)data;
+ (NSData *)hashBytes:(const unsigned char *)bytes length:(NSUInteger)length;
@end
