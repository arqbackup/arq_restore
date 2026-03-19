/*
 Arq7Node — port of arq7's Node.m.
 Changes: SETNSERROR_ARC → SETNSERROR, BlobLoc → Arq7BlobLoc.
*/

#import "Arq7Node.h"
#import "Arq7BlobLoc.h"
#import "BooleanIO.h"
#import "StringIO.h"
#import "IntegerIO.h"
#import "BufferedInputStream.h"


@interface Arq7Node() {
    BOOL _isTree;
    Arq7BlobLoc *_treeBlobLoc;
    Arq7ComputerOSType _computerOSType;
    NSArray *_dataBlobLocs;
    Arq7BlobLoc *_aclBlobLoc;
    NSArray *_xattrsBlobLocs;
    uint64_t _itemSize;
    uint64_t _containedFilesCount;
    int64_t _modificationTime_sec;
    int64_t _modificationTime_nsec;
    int64_t _changeTime_sec;
    int64_t _changeTime_nsec;
    int64_t _creationTime_sec;
    int64_t _creationTime_nsec;
    NSString *_userName;
    NSString *_groupName;
    BOOL _deleted;
    int32_t _mac_st_dev;
    uint64_t _mac_st_ino;
    uint16_t _mac_st_mode;
    uint16_t _mac_st_nlink;
    uint16_t _mac_st_uid;
    uint16_t _mac_st_gid;
    int32_t _mac_st_rdev;
    uint32_t _mac_st_flags;
    uint32_t _winAttrs;
    uint32_t _reparseTag;
    BOOL _reparsePointIsDirectory;
}
@end


@implementation Arq7Node

- (instancetype)initWithTreeBlobLoc:(Arq7BlobLoc *)theTreeBlobLoc
                     computerOSType:(Arq7ComputerOSType)theComputerOSType
                         aclBlobLoc:(Arq7BlobLoc *)theAclBlobLoc
                     xattrsBlobLocs:(NSArray *)theXattrsBlobLocs
                           itemSize:(uint64_t)theItemSize
                containedFilesCount:(uint64_t)theContainedFilesCount
               modificationTime_sec:(int64_t)theModificationTime_sec
              modificationTime_nsec:(int64_t)theModificationTime_nsec
                     changeTime_sec:(int64_t)theChangeTime_sec
                    changeTime_nsec:(int64_t)theChangeTime_nsec
                   creationTime_sec:(int64_t)theCreationTime_sec
                  creationTime_nsec:(int64_t)theCreationTime_nsec
                           userName:(NSString *)theUserName
                          groupName:(NSString *)theGroupName
                            deleted:(BOOL)theDeleted
                         mac_st_dev:(int32_t)theMac_st_dev
                         mac_st_ino:(uint64_t)theMac_st_ino
                        mac_st_mode:(uint16_t)theMac_st_mode
                       mac_st_nlink:(uint16_t)theMac_st_nlink
                         mac_st_uid:(uint16_t)theMac_st_uid
                         mac_st_gid:(uint16_t)theMac_st_gid
                        mac_st_rdev:(int32_t)theMac_st_rdev
                       mac_st_flags:(uint32_t)theMac_st_flags
                           winAttrs:(uint32_t)theWinAttrs
                         reparseTag:(uint32_t)theReparseTag {
    if (self = [super init]) {
        _isTree = YES;
        _dataBlobLocs = [NSArray array];
        _treeBlobLoc = theTreeBlobLoc;
        _computerOSType = theComputerOSType;
        _aclBlobLoc = theAclBlobLoc;
        _xattrsBlobLocs = theXattrsBlobLocs ? theXattrsBlobLocs : [NSArray array];
        _itemSize = theItemSize;
        _containedFilesCount = theContainedFilesCount;
        _modificationTime_sec = theModificationTime_sec;
        _modificationTime_nsec = theModificationTime_nsec;
        _changeTime_sec = theChangeTime_sec;
        _changeTime_nsec = theChangeTime_nsec;
        _creationTime_sec = theCreationTime_sec;
        _creationTime_nsec = theCreationTime_nsec;
        _userName = theUserName;
        _groupName = theGroupName;
        _deleted = theDeleted;
        _mac_st_dev = theMac_st_dev;
        _mac_st_ino = theMac_st_ino;
        _mac_st_mode = theMac_st_mode;
        _mac_st_nlink = theMac_st_nlink;
        _mac_st_uid = theMac_st_uid;
        _mac_st_gid = theMac_st_gid;
        _mac_st_rdev = theMac_st_rdev;
        _mac_st_flags = theMac_st_flags;
        _winAttrs = theWinAttrs;
        _reparseTag = theReparseTag;
    }
    return self;
}

- (instancetype)initWithDataBlobLocs:(NSArray *)theDataBlobLocs
                      computerOSType:(Arq7ComputerOSType)theComputerOSType
                          aclBlobLoc:(Arq7BlobLoc *)theAclBlobLoc
                      xattrsBlobLocs:(NSArray *)theXattrsBlobLocs
                            itemSize:(uint64_t)theItemSize
                 containedFilesCount:(uint64_t)theContainedFilesCount
                modificationTime_sec:(int64_t)theModificationTime_sec
               modificationTime_nsec:(int64_t)theModificationTime_nsec
                      changeTime_sec:(int64_t)theChangeTime_sec
                     changeTime_nsec:(int64_t)theChangeTime_nsec
                    creationTime_sec:(int64_t)theCreationTime_sec
                   creationTime_nsec:(int64_t)theCreationTime_nsec
                            userName:(NSString *)theUserName
                           groupName:(NSString *)theGroupName
                             deleted:(BOOL)theDeleted
                          mac_st_dev:(int32_t)theMac_st_dev
                          mac_st_ino:(uint64_t)theMac_st_ino
                         mac_st_mode:(uint16_t)theMac_st_mode
                        mac_st_nlink:(uint16_t)theMac_st_nlink
                          mac_st_uid:(uint16_t)theMac_st_uid
                          mac_st_gid:(uint16_t)theMac_st_gid
                         mac_st_rdev:(int32_t)theMac_st_rdev
                        mac_st_flags:(uint32_t)theMac_st_flags
                            winAttrs:(uint32_t)theWinAttrs
                          reparseTag:(uint32_t)theReparseTag
             reparsePointIsDirectory:(BOOL)theReparsePointIsDirectory {
    if (self = [super init]) {
        _isTree = NO;
        NSAssert(theDataBlobLocs != nil, @"theDataBlobLocs may not be nil");
        _dataBlobLocs = theDataBlobLocs;
        _computerOSType = theComputerOSType;
        _aclBlobLoc = theAclBlobLoc;
        _xattrsBlobLocs = theXattrsBlobLocs ? theXattrsBlobLocs : [NSArray array];
        _itemSize = theItemSize;
        _containedFilesCount = theContainedFilesCount;
        _modificationTime_sec = theModificationTime_sec;
        _modificationTime_nsec = theModificationTime_nsec;
        _changeTime_sec = theChangeTime_sec;
        _changeTime_nsec = theChangeTime_nsec;
        _creationTime_sec = theCreationTime_sec;
        _creationTime_nsec = theCreationTime_nsec;
        _userName = theUserName;
        _groupName = theGroupName;
        _deleted = theDeleted;
        _mac_st_dev = theMac_st_dev;
        _mac_st_ino = theMac_st_ino;
        _mac_st_mode = theMac_st_mode;
        _mac_st_nlink = theMac_st_nlink;
        _mac_st_uid = theMac_st_uid;
        _mac_st_gid = theMac_st_gid;
        _mac_st_rdev = theMac_st_rdev;
        _mac_st_flags = theMac_st_flags;
        _winAttrs = theWinAttrs;
        _reparseTag = theReparseTag;
        _reparsePointIsDirectory = theReparsePointIsDirectory;
    }
    return self;
}

- (instancetype)initWithJSON:(NSDictionary *)theJSON error:(NSError **)error {
    if (self = [super init]) {
        _isTree = [[theJSON objectForKey:@"isTree"] boolValue];
        if ([theJSON objectForKey:@"treeBlobLoc"] != nil) {
            _treeBlobLoc = [[Arq7BlobLoc alloc] initWithJSON:[theJSON objectForKey:@"treeBlobLoc"] error:error];
            if (_treeBlobLoc == nil) {
                return nil;
            }
        }
        _computerOSType = [[theJSON objectForKey:@"computerOSType"] unsignedIntValue];

        NSArray *dataBlobLocsJSON = [theJSON objectForKey:@"dataBlobLocs"];
        NSMutableArray *dataBlobLocs = [NSMutableArray array];
        for (NSDictionary *blobLocJSON in dataBlobLocsJSON) {
            Arq7BlobLoc *bl = [[Arq7BlobLoc alloc] initWithJSON:blobLocJSON error:error];
            if (bl == nil) {
                return nil;
            }
            [dataBlobLocs addObject:bl];
        }
        _dataBlobLocs = dataBlobLocs;

        NSDictionary *aclBlobLocJSON = [theJSON objectForKey:@"aclBlobLoc"];
        if (aclBlobLocJSON != nil) {
            _aclBlobLoc = [[Arq7BlobLoc alloc] initWithJSON:aclBlobLocJSON error:error];
            if (_aclBlobLoc == nil) {
                return nil;
            }
        }
        NSArray *xattrsBlobLocsJSON = [theJSON objectForKey:@"xattrsBlobLocs"];
        NSMutableArray *xattrsBlobLocs = [NSMutableArray array];
        for (NSDictionary *xattrsBlobLocJSON in xattrsBlobLocsJSON) {
            Arq7BlobLoc *bl = [[Arq7BlobLoc alloc] initWithJSON:xattrsBlobLocJSON error:error];
            if (bl == nil) {
                return nil;
            }
            [xattrsBlobLocs addObject:bl];
        }
        _xattrsBlobLocs = [xattrsBlobLocs copy];
        _itemSize = [[theJSON objectForKey:@"itemSize"] unsignedLongLongValue];
        _containedFilesCount = [[theJSON objectForKey:@"containedFilesCount"] unsignedLongLongValue];
        _modificationTime_sec = [[theJSON objectForKey:@"modificationTime_sec"] longLongValue];
        _modificationTime_nsec = [[theJSON objectForKey:@"modificationTime_nsec"] longLongValue];
        _changeTime_sec = [[theJSON objectForKey:@"changeTime_sec"] longLongValue];
        _changeTime_nsec = [[theJSON objectForKey:@"changeTime_nsec"] longLongValue];
        _creationTime_sec = [[theJSON objectForKey:@"creationTime_sec"] longLongValue];
        _creationTime_nsec = [[theJSON objectForKey:@"creationTime_nsec"] longLongValue];
        _userName = [theJSON objectForKey:@"userName"];
        _groupName = [theJSON objectForKey:@"groupName"];
        _deleted = [[theJSON objectForKey:@"deleted"] boolValue];
        _mac_st_dev = [[theJSON objectForKey:@"mac_st_dev"] intValue];
        _mac_st_ino = [[theJSON objectForKey:@"mac_st_ino"] unsignedLongLongValue];
        _mac_st_mode = (uint16_t)[[theJSON objectForKey:@"mac_st_mode"] unsignedIntValue];
        _mac_st_nlink = (uint16_t)[[theJSON objectForKey:@"mac_st_nlink"] unsignedIntValue];
        _mac_st_uid = (uint16_t)[[theJSON objectForKey:@"mac_st_uid"] unsignedIntValue];
        _mac_st_gid = (uint16_t)[[theJSON objectForKey:@"mac_st_gid"] unsignedIntValue];
        _mac_st_rdev = [[theJSON objectForKey:@"mac_st_rdev"] intValue];
        _mac_st_flags = [[theJSON objectForKey:@"mac_st_flags"] unsignedIntValue];
        _winAttrs = [[theJSON objectForKey:@"winAttrs"] unsignedIntValue];
        _reparseTag = [[theJSON objectForKey:@"reparseTag"] unsignedIntValue];
        _reparsePointIsDirectory = [[theJSON objectForKey:@"reparsePointIsDirectory"] boolValue];
    }
    return self;
}

- (instancetype)initWithBufferedInputStream:(BufferedInputStream *)bis
                                treeVersion:(int)theTreeVersion
                                      error:(NSError **)error {
    if (self = [super init]) {
        if (![BooleanIO read:&_isTree from:bis error:error]) {
            return nil;
        }
        if (_isTree) {
            _treeBlobLoc = [[Arq7BlobLoc alloc] initWithBufferedInputStream:bis treeVersion:theTreeVersion error:error];
            if (_treeBlobLoc == nil) {
                return nil;
            }
        }

        uint32_t computerOSType = 0;
        if (![IntegerIO readUInt32:&computerOSType from:bis error:error]) {
            return nil;
        }
        _computerOSType = (Arq7ComputerOSType)computerOSType;

        uint64_t count = 0;
        if (![IntegerIO readUInt64:&count from:bis error:error]) {
            return nil;
        }
        NSMutableArray *blobLocs = [NSMutableArray array];
        for (uint64_t i = 0; i < count; i++) {
            Arq7BlobLoc *bl = [[Arq7BlobLoc alloc] initWithBufferedInputStream:bis treeVersion:theTreeVersion error:error];
            if (bl == nil) {
                return nil;
            }
            [blobLocs addObject:bl];
        }
        _dataBlobLocs = blobLocs;

        BOOL aclBlobLocNotNil = NO;
        if (![BooleanIO read:&aclBlobLocNotNil from:bis error:error]) {
            return nil;
        }
        if (aclBlobLocNotNil) {
            _aclBlobLoc = [[Arq7BlobLoc alloc] initWithBufferedInputStream:bis treeVersion:theTreeVersion error:error];
            if (_aclBlobLoc == nil) {
                return nil;
            }
        }

        uint64_t xattrsBlobLocCount = 0;
        if (![IntegerIO readUInt64:&xattrsBlobLocCount from:bis error:error]) {
            return nil;
        }
        NSMutableArray *xattrsBlobLocs = [NSMutableArray array];
        for (uint64_t i = 0; i < xattrsBlobLocCount; i++) {
            Arq7BlobLoc *bl = [[Arq7BlobLoc alloc] initWithBufferedInputStream:bis treeVersion:theTreeVersion error:error];
            if (bl == nil) {
                return nil;
            }
            [xattrsBlobLocs addObject:bl];
        }
        _xattrsBlobLocs = xattrsBlobLocs;

        NSString *userName = nil;
        NSString *groupName = nil;
        BOOL deleted = NO;
        uint32_t st_mode = 0;
        uint32_t st_nlink = 0;
        uint32_t uid = 0;
        uint32_t gid = 0;
        if (![IntegerIO readUInt64:&_itemSize from:bis error:error]
            || ![IntegerIO readUInt64:&_containedFilesCount from:bis error:error]
            || ![IntegerIO readInt64:&_modificationTime_sec from:bis error:error]
            || ![IntegerIO readInt64:&_modificationTime_nsec from:bis error:error]
            || ![IntegerIO readInt64:&_changeTime_sec from:bis error:error]
            || ![IntegerIO readInt64:&_changeTime_nsec from:bis error:error]
            || ![IntegerIO readInt64:&_creationTime_sec from:bis error:error]
            || ![IntegerIO readInt64:&_creationTime_nsec from:bis error:error]
            || ![StringIO read:&userName from:bis error:error]
            || ![StringIO read:&groupName from:bis error:error]
            || ![BooleanIO read:&deleted from:bis error:error]
            || ![IntegerIO readInt32:&_mac_st_dev from:bis error:error]
            || ![IntegerIO readUInt64:&_mac_st_ino from:bis error:error]
            || ![IntegerIO readUInt32:&st_mode from:bis error:error]
            || ![IntegerIO readUInt32:&st_nlink from:bis error:error]
            || ![IntegerIO readUInt32:&uid from:bis error:error]
            || ![IntegerIO readUInt32:&gid from:bis error:error]
            || ![IntegerIO readInt32:&_mac_st_rdev from:bis error:error]
            || ![IntegerIO readUInt32:&_mac_st_flags from:bis error:error]
            || ![IntegerIO readUInt32:&_winAttrs from:bis error:error]) {
            return nil;
        }
        if (theTreeVersion >= 2) {
            if (![IntegerIO readUInt32:&_reparseTag from:bis error:error]
                || ![BooleanIO read:&_reparsePointIsDirectory from:bis error:error]) {
                return nil;
            }
        }
        _userName = userName;
        _groupName = groupName;
        _deleted = deleted;
        _mac_st_mode = (uint16_t)st_mode;
        _mac_st_nlink = (uint16_t)st_nlink;
        _mac_st_uid = (uint16_t)uid;
        _mac_st_gid = (uint16_t)gid;
    }
    return self;
}

- (NSString *)errorDomain {
    return @"Arq7NodeErrorDomain";
}

- (BOOL)isTree { return _isTree; }
- (Arq7BlobLoc *)treeBlobLoc { return _treeBlobLoc; }
- (Arq7ComputerOSType)computerOSType { return _computerOSType; }
- (NSArray *)dataBlobLocs { return _dataBlobLocs; }
- (Arq7BlobLoc *)aclBlobLoc { return _aclBlobLoc; }
- (NSArray *)xattrsBlobLocs { return _xattrsBlobLocs; }
- (uint64_t)itemSize { return _itemSize; }
- (uint64_t)containedFilesCount { return _containedFilesCount; }
- (int64_t)modificationTime_sec { return _modificationTime_sec; }
- (int64_t)modificationTime_nsec { return _modificationTime_nsec; }
- (int64_t)changeTime_sec { return _changeTime_sec; }
- (int64_t)changeTime_nsec { return _changeTime_nsec; }
- (int64_t)creationTime_sec { return _creationTime_sec; }
- (int64_t)creationTime_nsec { return _creationTime_nsec; }
- (NSString *)userName { return _userName; }
- (NSString *)groupName { return _groupName; }
- (BOOL)deleted { return _deleted; }
- (int32_t)mac_st_dev { return _mac_st_dev; }
- (uint64_t)mac_st_ino { return _mac_st_ino; }
- (uint16_t)mac_st_mode { return _mac_st_mode; }
- (uint16_t)mac_st_nlink { return _mac_st_nlink; }
- (uint16_t)mac_st_uid { return _mac_st_uid; }
- (uint16_t)mac_st_gid { return _mac_st_gid; }
- (int32_t)mac_st_rdev { return _mac_st_rdev; }
- (uint32_t)mac_st_flags { return _mac_st_flags; }
- (uint32_t)winAttrs { return _winAttrs; }
- (uint32_t)reparseTag { return _reparseTag; }
- (BOOL)reparsePointIsDirectory { return _reparsePointIsDirectory; }

- (NSString *)description {
    return [NSString stringWithFormat:@"<Arq7Node isTree=%@ itemSize=%qu>",
            (_isTree ? @"YES" : @"NO"), _itemSize];
}
@end
