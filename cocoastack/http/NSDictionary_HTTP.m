//
//  NSDictionary_HTTP.m
//  Arq
//
//  Created by Stefan Reitshamer on 7/4/11.
//  Copyright 2011 Haystack Software. All rights reserved.
//

#import "NSDictionary_HTTP.h"


@implementation NSDictionary (HTTP)
- (NSString *)wwwFormURLEncodedString {
    NSMutableString *ret = [NSMutableString string];
    for (NSString *key in [self allKeys]) {
        if ([ret length] > 0) {
            [ret appendString:@"&"];
        }
        if ([key isKindOfClass:[NSNumber class]]) {
            key = [(NSNumber *)key stringValue];
        }
        NSString *value = [self objectForKey:key];
        if ([value isKindOfClass:[NSNumber class]]) {
            value = [(NSNumber *)value stringValue];
        }
        NSString *encodedKey = (NSString *)CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (CFStringRef)key, NULL, CFSTR("?=&+"), kCFStringEncodingUTF8);
        NSString *encodedValue = (NSString *)CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (CFStringRef)value, NULL, CFSTR("?=&+"), kCFStringEncodingUTF8);
        [ret appendString:encodedKey];
        [ret appendString:@"="];
        [ret appendString:encodedValue];
        [encodedKey release];
        [encodedValue release];
    }
    return ret;
}
@end
