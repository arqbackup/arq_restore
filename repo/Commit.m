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


#import "IntegerIO.h"
#import "DateIO.h"
#import "StringIO.h"
#import "Commit.h"
#import "DataInputStream.h"
#import "RegexKitLite.h"
#import "CommitFailedFile.h"
#import "BufferedInputStream.h"
#import "BooleanIO.h"
#import "DataIO.h"
#import "BlobKey.h"

#define HEADER_LENGTH (10)

@interface Commit (internal)
- (BOOL)readHeader:(BufferedInputStream *)is error:(NSError **)error;
@end

@implementation Commit
+ (NSString *)errorDomain {
    return @"CommitErrorDomain";
}


@synthesize commitVersion,
author = _author, 
comment = _comment, 
treeBlobKey = _treeBlobKey, 
parentCommitBlobKey = _parentCommitBlobKey,
location = _location, 
computer = _computer,
creationDate = _creationDate,
commitFailedFiles = _commitFailedFiles,
hasMissingNodes = _hasMissingNodes,
isComplete = _isComplete,
bucketXMLData = _bucketXMLData;


- (id)initWithCommit:(Commit *)theCommit parentCommitBlobKey:(BlobKey *)theParentBlobKey {
    if (self = [super init]) {
        _author = [[theCommit author] copy];
        _comment = [[theCommit comment] copy];
        _parentCommitBlobKey = [theParentBlobKey retain];
        _treeBlobKey = [[theCommit treeBlobKey] copy];
        _location = [[theCommit location] copy];
        _computer = [[theCommit computer] copy];
        _creationDate = [[theCommit creationDate] copy];
        _commitFailedFiles = [[theCommit commitFailedFiles] copy];
        _hasMissingNodes = [theCommit hasMissingNodes];
        _isComplete = [theCommit isComplete];
        _bucketXMLData = [[theCommit bucketXMLData] copy];
    }
    return self;
}

- (id)             initWithAuthor:(NSString *)theAuthor 
                          comment:(NSString *)theComment 
              parentCommitBlobKey:(BlobKey *)theParentCommitBlobKey
                      treeBlobKey:(BlobKey *)theTreeBlobKey
                         location:(NSString *)theLocation
                     creationDate:(NSDate *)theCreationDate
                commitFailedFiles:(NSArray *)theCommitFailedFiles
                  hasMissingNodes:(BOOL)theHasMissingNodes
                       isComplete:(BOOL)theIsComplete
                    bucketXMLData:(NSData *)theBucketXMLData {
    if (self = [super init]) {
        commitVersion = CURRENT_COMMIT_VERSION;
        _author = [theAuthor copy];
        _comment = [theComment copy];
        _parentCommitBlobKey = [theParentCommitBlobKey retain];
        _treeBlobKey = [theTreeBlobKey retain];
        _location = [theLocation copy];
        NSRange computerRange = [_location rangeOfRegex:@"^file://([^/]+)/" capture:1];
        if (computerRange.location != NSNotFound) {
            _computer = [[_location substringWithRange:computerRange] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        } else {
            _computer = @"";
        }
        [_computer retain];
        _creationDate = [theCreationDate retain];
        _commitFailedFiles = [theCommitFailedFiles copy];
        _hasMissingNodes = theHasMissingNodes;
        _isComplete = theIsComplete;
        _bucketXMLData = [theBucketXMLData copy];
    }
    return self;
}
- (id)initWithBufferedInputStream:(BufferedInputStream *)is error:(NSError **)error {
	if (self = [super init]) {
        if (![self readHeader:is error:error]) {
            goto init_error;
        }
        if (![StringIO read:&_author from:is error:error]) {
            goto init_error;
        }
        [_author retain];
        
        if (![StringIO read:&_comment from:is error:error]) {
            goto init_error;
        }
        [_comment retain];
        
        uint64_t parentCommitKeyCount = 0;
        if (![IntegerIO readUInt64:&parentCommitKeyCount from:is error:error]) {
            goto init_error;
        }
        for (uint64_t i = 0; i < parentCommitKeyCount; i++) {
            NSString *key;
            BOOL cryptoKeyStretched = NO;
            if (![StringIO read:&key from:is error:error]) {
                goto init_error;
            }
            if (commitVersion >= 4) {
                if (![BooleanIO read:&cryptoKeyStretched from:is error:error]) {
                    goto init_error;
                }
            }
            if (_parentCommitBlobKey != nil) {
                HSLogError(@"IGNORING EXTRA PARENT COMMIT BLOB KEY!");
            } else {
                _parentCommitBlobKey = [[BlobKey alloc] initWithSHA1:key storageType:StorageTypeS3 stretchEncryptionKey:cryptoKeyStretched compressed:NO error:error];
                if (_parentCommitBlobKey == nil) {
                    goto init_error;
                }
            }
        }
        
        NSString *treeSHA1 = nil;
        BOOL treeStretchedKey = NO;
        if (![StringIO read:&treeSHA1 from:is error:error]) {
            goto init_error;
        }
        if (commitVersion >= 4) {
            if (![BooleanIO read:&treeStretchedKey from:is error:error]) {
                goto init_error;
            }
        }
        BOOL treeIsCompressed = NO;
        if (commitVersion >= 8) {
            if (![BooleanIO read:&treeIsCompressed from:is error:error]) {
                goto init_error;
            }
        }
        _treeBlobKey = [[BlobKey alloc] initWithSHA1:treeSHA1 storageType:StorageTypeS3 stretchEncryptionKey:treeStretchedKey compressed:treeIsCompressed error:error];
        if (_treeBlobKey == nil) {
            goto init_error;
        }
        
        if (![StringIO read:&_location from:is error:error]) {
            goto init_error;
        }
        [_location retain];
        
        NSRange computerRange = [_location rangeOfRegex:@"^file://([^/]+)/" capture:1];
        if (computerRange.location != NSNotFound) {
            _computer = [[_location substringWithRange:computerRange] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        } else {
            _computer = @"";
        }
        [_computer retain];
        
        // Removed mergeCommonAncestorCommitBlobKey in Commit version 8. It was never used.
        if (commitVersion < 8) {
            NSString *mergeCommonAncestorCommitSHA1 = nil;
            BOOL mergeCommonAncestorCommitStretchedKey = NO;
            if (![StringIO read:&mergeCommonAncestorCommitSHA1 from:is error:error]) {
                goto init_error;
            }
            if (commitVersion >= 4) {
                if (![BooleanIO read:&mergeCommonAncestorCommitStretchedKey from:is error:error]) {
                    goto init_error;
                }
            }
//            if (mergeCommonAncestorCommitSHA1 != nil) {
//                _mergeCommonAncestorCommitBlobKey = [[BlobKey alloc] initWithSHA1:mergeCommonAncestorCommitSHA1 stretchEncryptionKey:mergeCommonAncestorCommitStretchedKey];
//            }
        }
        
        if (![DateIO read:&_creationDate from:is error:error]) {
            goto init_error;
        }
        [_creationDate retain];
        if (commitVersion >= 3) {
            uint64_t commitFailedFileCount = 0;
            if (![IntegerIO readUInt64:&commitFailedFileCount from:is error:error]) {
                goto init_error;
            }
            NSMutableArray *commitFailedFiles = [NSMutableArray array];
            for (uint64_t index = 0; index < commitFailedFileCount; index++) {
                CommitFailedFile *cff = [[CommitFailedFile alloc] initWithInputStream:is error:error];
                if (cff == nil) {
                    goto init_error;
                }
                [commitFailedFiles addObject:cff];
                [cff release];
            }
            _commitFailedFiles = [commitFailedFiles retain];
        }
        
        if (commitVersion >= 8) {
            if (![BooleanIO read:&_hasMissingNodes from:is error:error]) {
                goto init_error;
            }
        }
        if (commitVersion >= 9) {
            if (![BooleanIO read:&_isComplete from:is error:error]) {
                goto init_error;
            }
        } else {
            _isComplete = YES;
        }
        if (commitVersion >= 5) {
            if (![DataIO read:&_bucketXMLData from:is error:error]) {
                goto init_error;
            }
            [_bucketXMLData retain];
        }
    }
    goto init_done;
    
init_error:
    [self release];
    self = nil;
    
init_done:
    return self;
}
- (void)dealloc {
    [_author release];
    [_comment release];
    [_parentCommitBlobKey release];
    [_treeBlobKey release];
    [_location release];
    [_computer release];
    [_creationDate release];
    [_commitFailedFiles release];
    [_bucketXMLData release];
    [super dealloc];
}
- (NSData *)toData {
    NSMutableData *data = [[[NSMutableData alloc] init] autorelease];
    char header[HEADER_LENGTH + 1];
    sprintf(header, "CommitV%03d", CURRENT_COMMIT_VERSION);
    [data appendBytes:header length:HEADER_LENGTH];
    [StringIO write:_author to:data];
    [StringIO write:_comment to:data];
    if (_parentCommitBlobKey == nil) {
        [IntegerIO writeUInt64:0 to:data];
    } else {
        [IntegerIO writeUInt64:1 to:data];
        [StringIO write:[_parentCommitBlobKey sha1] to:data];
        [BooleanIO write:[_parentCommitBlobKey stretchEncryptionKey] to:data];
    }
    [StringIO write:[_treeBlobKey sha1] to:data];
    [BooleanIO write:[_treeBlobKey stretchEncryptionKey] to:data];
    [BooleanIO write:[_treeBlobKey compressed] to:data];
    [StringIO write:_location to:data];
    [DateIO write:_creationDate to:data];
    uint64_t commitFailedFilesCount = (uint64_t)[_commitFailedFiles count];
    [IntegerIO writeUInt64:commitFailedFilesCount to:data];
    for (CommitFailedFile *cff in _commitFailedFiles) {
        [cff writeTo:data];
    }
    [BooleanIO write:_hasMissingNodes to:data];
    [BooleanIO write:_isComplete to:data];
    [DataIO write:_bucketXMLData to:data];
    return data;
}

#pragma mark NSObject
- (NSString *)description {
    return [NSString stringWithFormat:@"<Commit: created=%@ tree=%@ parent=%@ complete=%@ missingnodes=%@>", _creationDate, _treeBlobKey, _parentCommitBlobKey, (_isComplete ? @"YES" : @"NO"), (_hasMissingNodes ? @"YES" : @"NO")];
}
@end

@implementation Commit (internal)
- (BOOL)readHeader:(BufferedInputStream *)is error:(NSError **)error {
    BOOL ret = NO;
    unsigned char *buf = (unsigned char *)malloc(HEADER_LENGTH);
    if (![is readExactly:HEADER_LENGTH into:buf error:error]) {
        goto readHeader_error;
    }
    NSString *header = [[[NSString alloc] initWithBytes:buf length:HEADER_LENGTH encoding:NSASCIIStringEncoding] autorelease];
    if (![header hasPrefix:@"CommitV"] || [header length] < 8) {
        HSLogDebug(@"current Commit version: %d", CURRENT_COMMIT_VERSION);
        SETNSERROR([Commit errorDomain], ERROR_INVALID_COMMIT_HEADER, @"invalid header %@", header);
        goto readHeader_error;
    }
    commitVersion = [[header substringFromIndex:7] intValue];
    if (commitVersion > CURRENT_COMMIT_VERSION || commitVersion < 2) {
        SETNSERROR([Commit errorDomain], ERROR_INVALID_OBJECT_VERSION, @"invalid Commit version %d", commitVersion);
        goto readHeader_error;
    }
    ret = YES;
readHeader_error:
    free(buf);
    return ret;
}
@end
