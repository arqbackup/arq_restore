//
//  Commit.m
//  Backup
//
//  Created by Stefan Reitshamer on 3/21/09.
//  Copyright 2009 PhotoMinds LLC. All rights reserved.
//

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


@synthesize author = _author, 
comment = _comment, 
treeBlobKey = _treeBlobKey, 
parentCommitBlobKeys = _parentCommitBlobKeys, 
location = _location, 
computer = _computer,
mergeCommonAncestorCommitBlobKey = _mergeCommonAncestorCommitBlobKey, 
creationDate = _creationDate,
commitFailedFiles = _commitFailedFiles,
bucketXMLData = _bucketXMLData;


- (id)initWithCommit:(Commit *)theCommit parentCommitBlobKey:(BlobKey *)theParentBlobKey {
    if (self = [super init]) {
        _author = [[theCommit author] copy];
        _comment = [[theCommit comment] copy];
        if (theParentBlobKey != nil) {
            _parentCommitBlobKeys = [[NSMutableSet alloc] initWithObjects:theParentBlobKey, nil];
        } else {
            _parentCommitBlobKeys = [[NSMutableSet alloc] init];
        }
        _treeBlobKey = [[theCommit treeBlobKey] copy];
        _location = [[theCommit location] copy];
        _computer = [[theCommit computer] copy];
        _mergeCommonAncestorCommitBlobKey = nil;
        _creationDate = [[theCommit creationDate] copy];
        _commitFailedFiles = [[theCommit commitFailedFiles] copy];
        _bucketXMLData = [[theCommit bucketXMLData] copy];
    }
    return self;
}

- (id)             initWithAuthor:(NSString *)theAuthor 
                          comment:(NSString *)theComment 
             parentCommitBlobKeys:(NSSet *)theParentCommitBlobKeys 
                      treeBlobKey:(BlobKey *)theTreeBlobKey
                         location:(NSString *)theLocation
 mergeCommonAncestorCommitBlobKey:(BlobKey *)theMergeCommonAncestorCommitBlobKey 
                commitFailedFiles:(NSArray *)theCommitFailedFiles 
                    bucketXMLData:(NSData *)theBucketXMLData {
    if (self = [super init]) {
        _author = [theAuthor copy];
        _comment = [theComment copy];
        _parentCommitBlobKeys = [[NSMutableSet alloc] initWithSet:theParentCommitBlobKeys];
        _treeBlobKey = [theTreeBlobKey retain];
        _location = [theLocation copy];
        NSRange computerRange = [_location rangeOfRegex:@"^file://([^/]+)/" capture:1];
        if (computerRange.location != NSNotFound) {
            _computer = [[_location substringWithRange:computerRange] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        } else {
            _computer = @"";
        }
        [_computer retain];
        _mergeCommonAncestorCommitBlobKey = [theMergeCommonAncestorCommitBlobKey retain];
        _creationDate = [[NSDate alloc] init];
        _commitFailedFiles = [theCommitFailedFiles copy];
        _bucketXMLData = [theBucketXMLData copy];
    }
    return self;
}
- (id)initWithBufferedInputStream:(BufferedInputStream *)is error:(NSError **)error {
	if (self = [super init]) {
        _parentCommitBlobKeys = [[NSMutableSet alloc] init];
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
            BlobKey *parentBlobKey = [[BlobKey alloc] initWithSHA1:key stretchEncryptionKey:cryptoKeyStretched];
            [_parentCommitBlobKeys addObject:parentBlobKey];
            [parentBlobKey release];
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
        _treeBlobKey = [[BlobKey alloc] initWithSHA1:treeSHA1 stretchEncryptionKey:treeStretchedKey];
        
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
        if (mergeCommonAncestorCommitSHA1 != nil) {
            _mergeCommonAncestorCommitBlobKey = [[BlobKey alloc] initWithSHA1:mergeCommonAncestorCommitSHA1 stretchEncryptionKey:mergeCommonAncestorCommitStretchedKey];
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
    [_parentCommitBlobKeys release];
    [_treeBlobKey release];
    [_location release];
    [_computer release];
    [_mergeCommonAncestorCommitBlobKey release];
    [_creationDate release];
    [_commitFailedFiles release];
    [_bucketXMLData release];
    [super dealloc];
}
- (NSNumber *)isMergeCommit {
    return [NSNumber numberWithBool:([_parentCommitBlobKeys count] > 1)];
}
- (Blob *)toBlob {
    Blob *ret = nil;
    NSMutableData *data = [[NSMutableData alloc] init];
    char header[HEADER_LENGTH + 1];
    sprintf(header, "CommitV%03d", CURRENT_COMMIT_VERSION);
    [data appendBytes:header length:HEADER_LENGTH];
    [StringIO write:_author to:data];
    [StringIO write:_comment to:data];
    uint64_t parentCommitBlobKeysCount = (uint64_t)[_parentCommitBlobKeys count];
    [IntegerIO writeUInt64:parentCommitBlobKeysCount to:data];
    for (BlobKey *parentCommitBlobKey in _parentCommitBlobKeys) {
        [StringIO write:[parentCommitBlobKey sha1] to:data];
        [BooleanIO write:[parentCommitBlobKey stretchEncryptionKey] to:data];
    }
    [StringIO write:[_treeBlobKey sha1] to:data];
    [BooleanIO write:[_treeBlobKey stretchEncryptionKey] to:data];
    [StringIO write:_location to:data];
    [StringIO write:[_mergeCommonAncestorCommitBlobKey sha1] to:data];
    [BooleanIO write:[_mergeCommonAncestorCommitBlobKey stretchEncryptionKey] to:data];
    [DateIO write:_creationDate to:data];
    uint64_t commitFailedFilesCount = (uint64_t)[_commitFailedFiles count];
    [IntegerIO writeUInt64:commitFailedFilesCount to:data];
    for (CommitFailedFile *cff in _commitFailedFiles) {
        [cff writeTo:data];
    }
    [DataIO write:_bucketXMLData to:data];
    ret = [[[Blob alloc] initWithData:data mimeType:@"binary/octet-stream" downloadName:@"commit" dataDescription:@"commit"] autorelease];
    [data release];
    return ret;
}

#pragma mark NSObject
- (NSString *)description {
    return [NSString stringWithFormat:@"<Commit: created=%@ tree=%@ parents=%@>", _creationDate, _treeBlobKey, _parentCommitBlobKeys];
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
    NSRange versionRange = [header rangeOfRegex:@"^CommitV(\\d{3})$" capture:1];
    commitVersion = 0;
    if (versionRange.location != NSNotFound) {
        NSNumberFormatter *nf = [[NSNumberFormatter alloc] init];
        NSNumber *number = [nf numberFromString:[header substringWithRange:versionRange]];
        commitVersion = [number intValue];
        [nf release];
    }
    if (commitVersion > CURRENT_COMMIT_VERSION || commitVersion < 2) {
        SETNSERROR([Commit errorDomain], ERROR_INVALID_OBJECT_VERSION, @"invalid Commit header");
        goto readHeader_error;
    }
    ret = YES;
readHeader_error:
    free(buf);
    return ret;
}
@end
