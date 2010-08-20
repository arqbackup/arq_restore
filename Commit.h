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

#import <Cocoa/Cocoa.h>
#import "Blob.h"
#import "BufferedInputStream.h"

#define CURRENT_COMMIT_VERSION 3

@interface Commit : NSObject {
    int commitVersion;
	NSString *_author;
	NSString *_comment;
	NSMutableSet *_parentCommitSHA1s;
	NSString *_treeSHA1;
	NSString *_location;
    NSString *_computer;
	NSString *_mergeCommonAncestorCommitSHA1;
	NSDate *_creationDate;
    NSArray *_commitFailedFiles;
}
- (id)initWithBufferedInputStream:(BufferedInputStream *)is error:(NSError **)error;

@property(readonly,copy) NSString *author;
@property(readonly,copy) NSString *comment;
@property(readonly,copy) NSString *treeSHA1;
@property(readonly,retain) NSSet *parentCommitSHA1s;
@property(readonly,copy) NSString *location;
@property(readonly,copy) NSString *computer;
@property(readonly,copy) NSString *mergeCommonAncestorCommitSHA1;
@property(readonly,retain) NSDate *creationDate;
@property(readonly,retain) NSArray *commitFailedFiles;
@end
