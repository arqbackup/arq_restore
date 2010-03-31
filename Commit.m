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

#import "IntegerIO.h"
#import "DateIO.h"
#import "StringIO.h"
#import "Commit.h"
#import "Blob.h"
#import "DataInputStream.h"
#import "RegexKitLite.h"
#import "SetNSError.h"
#import "NSErrorCodes.h"
#import "CommitFailedFile.h"

#define HEADER_LENGTH (10)

@interface Commit (internal)
- (BOOL)readHeader:(id <BufferedInputStream>)is error:(NSError **)error;
@end

@implementation Commit
@synthesize author = _author, 
comment = _comment, 
treeSHA1 = _treeSHA1, 
parentCommitSHA1s = _parentCommitSHA1s, 
location = _location, 
computer = _computer,
mergeCommonAncestorCommitSHA1 = _mergeCommonAncestorCommitSHA1, 
creationDate = _creationDate,
commitFailedFiles = _commitFailedFiles;

- (id)initWithBufferedInputStream:(id <BufferedInputStream>)is error:(NSError **)error {
	if (self = [super init]) {
        _parentCommitSHA1s = [[NSMutableSet alloc] init];
        if (![self readHeader:is error:error]) {
            [self release];
            return nil;
        }
        BOOL ret = NO;
        do {
            if (![StringIO read:&_author from:is error:error]) {
                break;
            }
            [_author retain];
            
            if (![StringIO read:&_comment from:is error:error]) {
                break;
            }
            [_comment retain];
            
            uint64_t parentCommitKeyCount = 0;
            if (![IntegerIO readUInt64:&parentCommitKeyCount from:is error:error]) {
                break;
            }
            for (uint64_t i = 0; i < parentCommitKeyCount; i++) {
                NSString *key;
                if (![StringIO read:&key from:is error:error]) {
                    break;
                }
                [_parentCommitSHA1s addObject:key];
            }
            
            if (![StringIO read:&_treeSHA1 from:is error:error]) {
                break;
            }
            [_treeSHA1 retain];
            
            if (![StringIO read:&_location from:is error:error]) {
                break;
            }
            [_location retain];
            
            NSRange computerRange = [_location rangeOfRegex:@"^file://([^/]+)/" capture:1];
            if (computerRange.location != NSNotFound) {
                _computer = [[_location substringWithRange:computerRange] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
            } else {
                _computer = @"";
            }
            [_computer retain];
            
            if (![StringIO read:&_mergeCommonAncestorCommitSHA1 from:is error:error]) {
                break;
            }
            [_mergeCommonAncestorCommitSHA1 retain];
            
            if (![DateIO read:&_creationDate from:is error:error]) {
                break;
            }
            [_creationDate retain];
            if (commitVersion >= 3) {
                uint64_t commitFailedFileCount = 0;
                if (![IntegerIO readUInt64:&commitFailedFileCount from:is error:error]) {
                    break;
                }
                NSMutableArray *commitFailedFiles = [NSMutableArray array];
                for (uint64_t index = 0; index < commitFailedFileCount; index++) {
                    CommitFailedFile *cff = [[CommitFailedFile alloc] initWithInputStream:is error:error];
                    if (cff == nil) {
                        break;
                    }
                    [commitFailedFiles addObject:cff];
                    [cff release];
                }
                _commitFailedFiles = [commitFailedFiles retain];
            }
            ret = YES;
        } while (0);
        if (!ret) {
            [self release];
            self = nil;
        }
    }
    return self;
}
- (void)release {
    [super release];
}
- (void)dealloc {
    [_author release];
    [_comment release];
    [_parentCommitSHA1s release];
    [_treeSHA1 release];
    [_location release];
    [_computer release];
    [_mergeCommonAncestorCommitSHA1 release];
    [_creationDate release];
    [_commitFailedFiles release];
    [super dealloc];
}
@end

@implementation Commit (internal)
- (BOOL)readHeader:(id <BufferedInputStream>)is error:(NSError **)error {
    unsigned char *headerBytes = [is readExactly:HEADER_LENGTH error:error];
    if (headerBytes == NULL) {
        return NO;
    }
    NSString *header = [[[NSString alloc] initWithBytes:headerBytes length:HEADER_LENGTH encoding:NSASCIIStringEncoding] autorelease];
    NSRange versionRange = [header rangeOfRegex:@"^CommitV(\\d{3})$" capture:1];
    commitVersion = 0;
    if (versionRange.location != NSNotFound) {
        NSNumberFormatter *nf = [[NSNumberFormatter alloc] init];
        NSNumber *number = [nf numberFromString:[header substringWithRange:versionRange]];
        commitVersion = [number intValue];
        [nf release];
    }
    if (commitVersion > CURRENT_COMMIT_VERSION || commitVersion < 2) {
        SETNSERROR(@"TreeErrorDomain", ERROR_INVALID_OBJECT_VERSION, @"invalid Commit header");
        return NO;
    }
    return YES;
    
}
@end
