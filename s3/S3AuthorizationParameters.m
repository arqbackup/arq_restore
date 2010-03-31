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

#import "S3AuthorizationParameters.h"
#import "HTTPRequest.h"

@implementation S3AuthorizationParameters
@synthesize bucketName, httpVerb, contentType, pathInfo, subResource, queryString, date, xamzHeaders;

- (id)initWithHTTPRequest:(HTTPRequest *)req s3BucketName:(NSString *)theS3BucketName {
    if (self = [super init]) {
		NSMutableArray *theXAmzHeaders = [[NSMutableArray alloc ]init];
        bucketName = [theS3BucketName copy];
		httpVerb = [[req method] retain];
		pathInfo = [[req pathInfo] retain];
		contentType = [[req headerForKey:@"Content-Type"] retain];
		if (!contentType) {
			contentType = [[NSString alloc] initWithString:@""];
		}
		date = [[req headerForKey:@"Date"] retain];
		queryString = [[req queryString] retain];
		if (queryString != nil 
			&& ([queryString isEqualToString:@"?acl"] 
				|| [queryString isEqualToString:@"?logging"] 
				|| [queryString isEqualToString:@"?torrent"] 
				|| [queryString isEqualToString:@"?location"])) {
			subResource = queryString;
			queryString = [[NSString alloc] initWithString:@""];
		}
        for (NSString *headerName in [req allHeaderKeys]) {
			NSString *lowerCaseHeader = [headerName lowercaseString];
			if ([lowerCaseHeader hasPrefix:@"x-amz-"]) {
				[theXAmzHeaders addObject:[NSString stringWithFormat:@"%@:%@", headerName, [req headerForKey:headerName]]];
			}
		}
		[theXAmzHeaders sortUsingSelector:@selector(compare:)];
		xamzHeaders = theXAmzHeaders;
	}
	return self;
}
- (void)dealloc {
    [bucketName release];
    [httpVerb release];
    [contentType release];
    [pathInfo release];
    [subResource release];
    [queryString release];
    [date release];
    [xamzHeaders release];
    [super dealloc];
}
@end
