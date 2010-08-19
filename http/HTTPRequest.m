/*
 Copyright (c) 2009, Stefan Reitshamer http://www.haystacksoftware.com
 
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

#import "HTTPRequest.h"
#import "Writer.h"
#import "RFC2616DateFormatter.h"

#define DEFAULT_HTTP_PORT (80)

@implementation HTTPRequest
@synthesize host, method, pathInfo, queryString, protocol;

- (id)initWithHost:(NSString *)theHost {
    if (self = [super init]) {
        host = [theHost retain];
        headers = [[NSMutableDictionary alloc] init];
        dateFormatter = [[RFC2616DateFormatter alloc] init];
    }
    return self;
}

- (void)dealloc {
    [host release];
    [method release];
    [pathInfo release];
    [queryString release];
    [protocol release];
    [headers release];
    [dateFormatter release];
    [super dealloc];
}
- (void)setHeader:(NSString *)value forKey:(NSString *)key {
    [headers setValue:value forKey:key];
}
- (void)setHostHeader {
    [headers setValue:host forKey:@"Host"];
}
- (void)setKeepAliveHeader {
    [headers setValue:@"keep-alive" forKey:@"Connection"];
}
- (void)setRFC822DateHeader {
    [headers setValue:[dateFormatter rfc2616StringFromDate:[NSDate date]] forKey:@"Date"];
}
- (void)setContentDispositionHeader:(NSString *)downloadName {
    if (downloadName != nil) {
        NSString *encodedFilename = [NSString stringWithFormat:@"\"%@\"", [downloadName stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\\\""]];
        encodedFilename = [encodedFilename stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"];
        NSString *contentDisposition = [NSString stringWithFormat:@"attachment;filename=%@", encodedFilename];
        [self setHeader:contentDisposition forKey:@"Content-Disposition"];
    }
}
- (NSString *)headerForKey:(NSString *)key {
    return [headers objectForKey:key];
}
- (NSArray *)allHeaderKeys {
    return [headers allKeys];
}
- (BOOL)write:(id <OutputStream>)os error:(NSError **)error {
    HSLogTrace(@"writing %@", self);
    Writer *writer = [[Writer alloc] initWithOutputStream:os];
    BOOL ret = NO;
    do {
        if (![writer write:method error:error]
            || ![writer write:@" " error:error]
            || ![writer write:pathInfo error:error]) {
            break;
        }
        if (queryString != nil) {
            if (![writer write:queryString error:error]) {
                break;
            }
        }
        if (![writer write:@" HTTP/" error:error] 
            || ![writer write:protocol error:error]
            || ![writer write:@"\r\n" error:error]) {
            break;
        }
        for (NSString *key in [headers allKeys]) {
            HSLogTrace(@"header: %@ = %@", key, [headers objectForKey:key]);
            if (![writer write:key error:error]
                || ![writer write:@": " error:error]
                || ![writer write:[headers objectForKey:key] error:error]
                || ![writer write:@"\r\n" error:error]) {
                break;
            }
        }
        if (![writer write:@"\r\n" error:error]) {
            break;
        }
        ret = YES;
    } while(0);
    [writer release];
    return ret;
}

#pragma mark NSObject protocol
- (NSString *)description {
    return [NSString stringWithFormat:@"<HTTPRequest: %@ %@%@ HTTP/%@>", method, pathInfo, (queryString != nil ? queryString : @""), protocol];
}
@end
