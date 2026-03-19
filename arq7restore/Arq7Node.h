/*
 Arq7Node — port of arq7's Node.h for use in arq_restore.
 Uses Arq7* prefix to avoid conflicts with arq_restore's existing Arq5 Node class.
*/

#import "Arq7Types.h"
@class Arq7BlobLoc;
@class BufferedInputStream;

@interface Arq7Node : NSObject

- (instancetype)init NS_UNAVAILABLE;

// Tree node initializer
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
                         reparseTag:(uint32_t)theReparseTag;

// File node initializer
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
             reparsePointIsDirectory:(BOOL)theReparsePointIsDirectory;

- (instancetype)initWithJSON:(NSDictionary *)theJSON error:(NSError **)error;
- (instancetype)initWithBufferedInputStream:(BufferedInputStream *)bis
                                treeVersion:(int)theTreeVersion
                                      error:(NSError **)error;

- (BOOL)isTree;
- (Arq7BlobLoc *)treeBlobLoc;
- (Arq7ComputerOSType)computerOSType;
- (NSArray *)dataBlobLocs;
- (Arq7BlobLoc *)aclBlobLoc;
- (NSArray *)xattrsBlobLocs;
- (uint64_t)itemSize;
- (uint64_t)containedFilesCount;
- (int64_t)modificationTime_sec;
- (int64_t)modificationTime_nsec;
- (int64_t)changeTime_sec;
- (int64_t)changeTime_nsec;
- (int64_t)creationTime_sec;
- (int64_t)creationTime_nsec;
- (NSString *)userName;
- (NSString *)groupName;
- (BOOL)deleted;
- (int32_t)mac_st_dev;
- (uint64_t)mac_st_ino;
- (uint16_t)mac_st_mode;
- (uint16_t)mac_st_nlink;
- (uint16_t)mac_st_uid;
- (uint16_t)mac_st_gid;
- (int32_t)mac_st_rdev;
- (uint32_t)mac_st_flags;
- (uint32_t)winAttrs;
- (uint32_t)reparseTag;
- (BOOL)reparsePointIsDirectory;
@end
