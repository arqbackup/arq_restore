//
//  NSError_Glacier.h
//  Arq
//
//  Created by Stefan Reitshamer on 9/7/12.
//
//


@interface NSError (Glacier)
+ (NSError *)glacierErrorWithDomain:(NSString *)theDomain httpStatusCode:(int)theHTTPStatusCode responseBody:(NSData *)theResponseBody;
@end
