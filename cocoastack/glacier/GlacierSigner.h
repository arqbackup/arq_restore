//
//  GlacierSigner.h
//  Arq
//
//  Created by Stefan Reitshamer on 9/7/12.
//
//


@protocol GlacierSigner <NSObject>
- (NSString *)signString:(NSString *)theString withDateStamp:(NSString *)theDateStamp regionName:(NSString *)theRegionName serviceName:(NSString *)theServiceName;
@end
