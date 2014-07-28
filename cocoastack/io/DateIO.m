/*
 Copyright (c) 2009-2014, Stefan Reitshamer http://www.haystacksoftware.com
 
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


#import "BooleanIO.h"
#import "IntegerIO.h"
#import "DateIO.h"
#import "BufferedInputStream.h"

@implementation DateIO
+ (void)write:(NSDate *)date to:(NSMutableData *)data {
	BOOL dateNotNil = (date != nil);
	[BooleanIO write:dateNotNil to:data];
	if (dateNotNil) {
		long long millisecondsSince1970 = (long long)([date timeIntervalSince1970] * 1000.0);
		[IntegerIO writeInt64:millisecondsSince1970 to:data];
	}
}
+ (BOOL)write:(NSDate *)date to:(BufferedOutputStream *)bos error:(NSError **)error {
	BOOL dateNotNil = (date != nil);
    if (![BooleanIO write:dateNotNil to:bos error:error]) {
        return NO;
    }
    if (dateNotNil) {
		long long millisecondsSince1970 = (long long)([date timeIntervalSince1970] * 1000.0);
        if (![IntegerIO writeInt64:millisecondsSince1970 to:bos error:error]) {
            return NO;
        }
    }
    return YES;
}
+ (BOOL)read:(NSDate **)date from:(BufferedInputStream *)is error:(NSError **)error {
    *date = nil;
    BOOL notNil;
    if (![BooleanIO read:&notNil from:is error:error]) {
        return NO;
    }
    if (notNil) {
		long long millisecondsSince1970;
        if (![IntegerIO readInt64:&millisecondsSince1970 from:is error:error]) {
            return NO;
        }
        *date = [NSDate dateWithTimeIntervalSince1970:((double)millisecondsSince1970 / 1000.0)];
    }
    return YES;
}
@end
