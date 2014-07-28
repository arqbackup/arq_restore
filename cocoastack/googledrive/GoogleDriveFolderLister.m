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


#import "GoogleDriveFolderLister.h"
#import "GoogleDriveRequest.h"
#import "NSString+SBJSON.h"
#import "GoogleDrive.h"


static NSString *kURLQueryAllowedCharacterSet = @"\"#%<>[\\]^`{|}";

@implementation GoogleDriveFolderLister
- (id)initWithEmailAddress:(NSString *)theEmailAddress refreshToken:(NSString *)theRefreshToken folderId:(NSString *)theFolderId googleDriveDelegate:(id <GoogleDriveDelegate>)theGDD targetConnectionDelegate:(id<TargetConnectionDelegate>)theTCD {
    return [self initWithEmailAddress:theEmailAddress refreshToken:theRefreshToken folderId:theFolderId name:nil googleDriveDelegate:theGDD targetConnectionDelegate:theTCD];
}
- (id)initWithEmailAddress:(NSString *)theEmailAddress refreshToken:(NSString *)theRefreshToken folderId:(NSString *)theFolderId name:(NSString *)theName googleDriveDelegate:(id <GoogleDriveDelegate>)theGDD targetConnectionDelegate:(id<TargetConnectionDelegate>)theTCD {
    if (self = [super init]) {
        emailAddress = [theEmailAddress retain];
        refreshToken = [theRefreshToken retain];
        folderId = [theFolderId retain];
        fileName = [theName retain];
        googleDriveDelegate = theGDD;
        targetConnectionDelegate = theTCD;
    }
    return self;
}
- (void)dealloc {
    [emailAddress release];
    [refreshToken release];
    [folderId release];
    [fileName release];
    [pageToken release];
    [super dealloc];
}
- (NSArray *)googleDriveItems:(NSError **)error {
    NSMutableArray *ret = [NSMutableArray array];
    
    NSAutoreleasePool *pool = nil;
    for (;;) {
        [pool drain];
        pool = [[NSAutoreleasePool alloc] init];
        
        NSArray *items = [self nextPage:error];
        if (items == nil) {
            ret = nil;
            break;
        }
        
        [ret addObjectsFromArray:items];
        if (pageToken == nil) {
            break;
        }
    }
    
    [ret retain];
    if (ret == nil && error != NULL) {
        [*error retain];
    }
    [pool drain];
    [ret autorelease];
    if (ret == nil && error != NULL) {
        [*error autorelease];
    }
    return ret;
}

- (NSArray *)nextPage:(NSError **)error {
    if (folderId == nil) {
        SETNSERROR([GoogleDrive errorDomain], -1, @"folderId is nil!");
        return nil;
    }
    
    NSString *queryString = @"maxResults=1000&q=";
    NSString *search = [NSString stringWithFormat:@"explicitlyTrashed = false and '%@' in parents", folderId];
    if (fileName != nil) {
        NSString *escapedFileName = [fileName stringByReplacingOccurrencesOfString:@"'" withString:@"\\'"];
        search = [search stringByAppendingFormat:@" and title = '%@'", escapedFileName];
    }
    NSString *escapedSearch = [(NSString *)CFURLCreateStringByAddingPercentEscapes(NULL,
                                                                                   (CFStringRef)search,
                                                                                   (CFStringRef)@"",
                                                                                   (CFStringRef)kURLQueryAllowedCharacterSet,
                                                                                   kCFStringEncodingUTF8) autorelease];
    queryString = [queryString stringByAppendingString:escapedSearch];
    
    if (pageToken != nil) {
        NSString *escapedPageToken = [(NSString *)CFURLCreateStringByAddingPercentEscapes(NULL,
                                                                                          (CFStringRef)pageToken,
                                                                                          (CFStringRef)@"",
                                                                                          (CFStringRef)kURLQueryAllowedCharacterSet,
                                                                                          kCFStringEncodingUTF8) autorelease];
        queryString = [queryString stringByAppendingFormat:@"&pageToken=%@", escapedPageToken];
    }
    
    GoogleDriveRequest *req = [[[GoogleDriveRequest alloc] initWithEmailAddress:emailAddress
                                                                         method:@"GET"
                                                                           path:@"/drive/v2/files"
                                                                    queryString:queryString
                                                                   refreshToken:refreshToken
                                                            googleDriveDelegate:googleDriveDelegate
                                                           dataTransferDelegate:nil
                                                                          error:error] autorelease];
    if (req == nil) {
        return nil;
    }
    NSData *response = [req dataWithTargetConnectionDelegate:targetConnectionDelegate error:error];
    if (response == nil) {
        return nil;
    }
    NSString *responseString = [[[NSString alloc] initWithData:response encoding:NSUTF8StringEncoding] autorelease];
    NSDictionary *json = (NSDictionary *)[responseString JSONValue:error];
    if (json == nil) {
        return nil;
    }
    
    [pageToken release];
    pageToken = [[json objectForKey:@"nextPageToken"] retain];
    
    NSArray *items = [json objectForKey:@"items"];
    return items;
}
@end
