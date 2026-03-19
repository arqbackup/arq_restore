#import "Arq7Restorer.h"
#import "Arq7KeySet.h"
#import "Arq7BackupRecord.h"
#import "Arq7BlobReader.h"
#import "Arq7BlobLoc.h"
#import "Arq7Node.h"
#import "Arq7Tree.h"
#import "TargetConnection.h"
#import "FileAttributes.h"
#import "XAttrSet.h"
#import "DataInputStream.h"
#import "BufferedInputStream.h"
#include <sys/stat.h>
#include <utime.h>


@interface Arq7Restorer() {
    NSString *_planUUID;
    NSString *_folderUUID;
    TargetConnection *_conn;
    Arq7KeySet *_keySet;
    NSString *_relativePath;
    NSString *_destinationPath;
    id <TargetConnectionDelegate> _delegate;
    Arq7BlobReader *_blobReader;
}
@end


@implementation Arq7Restorer

- (instancetype)initWithPlanUUID:(NSString *)thePlanUUID
                      folderUUID:(NSString *)theFolderUUID
                targetConnection:(TargetConnection *)theConn
                          keySet:(Arq7KeySet *)theKeySet
                    relativePath:(NSString *)theRelativePath
                 destinationPath:(NSString *)theDestinationPath
                        delegate:(id <TargetConnectionDelegate>)theDelegate {
    if (self = [super init]) {
        _planUUID = thePlanUUID;
        _folderUUID = theFolderUUID;
        _conn = theConn;
        _keySet = theKeySet;
        _relativePath = theRelativePath;
        _destinationPath = theDestinationPath;
        _delegate = theDelegate;
    }
    return self;
}

- (NSString *)errorDomain {
    return @"Arq7RestorerErrorDomain";
}

- (BOOL)restore:(NSError **)error {
    // Load most recent complete backup record.
    Arq7BackupRecord *record = [Arq7BackupRecord mostRecentBackupRecordForPlanUUID:_planUUID
                                                                        folderUUID:_folderUUID
                                                                  targetConnection:_conn
                                                                            keySet:_keySet
                                                                          delegate:_delegate
                                                                             error:error];
    if (record == nil) {
        return NO;
    }

    printf("restoring backup from %s\n", [[record.creationDate description] UTF8String]);

    _blobReader = [[Arq7BlobReader alloc] initWithPlanUUID:_planUUID
                                          targetConnection:_conn
                                                    keySet:_keySet
                                                  delegate:_delegate];

    if (record.node == nil) {
        SETNSERROR([self errorDomain], -1, @"backup record has no node (version %d — Arq5-compat records not supported in Arq7Restorer)", record.version);
        return NO;
    }

    // The root node should be a tree node.
    if (![record.node isTree]) {
        SETNSERROR([self errorDomain], -1, @"root node is not a directory");
        return NO;
    }

    // Fetch the root tree.
    Arq7Tree *rootTree = [_blobReader treeForBlobLoc:record.node.treeBlobLoc error:error];
    if (rootTree == nil) {
        return NO;
    }

    // Walk to relative path if specified.
    if (_relativePath != nil) {
        NSString *path = _relativePath;
        if ([path hasPrefix:@"/"]) {
            path = [path substringFromIndex:1];
        }
        NSArray *components = [path pathComponents];
        Arq7Tree *currentTree = rootTree;
        for (NSUInteger i = 0; i < [components count]; i++) {
            NSString *component = [components objectAtIndex:i];
            Arq7Node *childNode = [currentTree childNodeWithName:component];
            if (childNode == nil) {
                SETNSERROR([self errorDomain], ERROR_NOT_FOUND, @"path component '%@' not found", component);
                return NO;
            }
            if ([childNode isTree]) {
                currentTree = [_blobReader treeForBlobLoc:childNode.treeBlobLoc error:error];
                if (currentTree == nil) {
                    return NO;
                }
                if (i == [components count] - 1) {
                    // Last component is a directory — restore this subtree.
                    return [self restoreTree:currentTree toPath:_destinationPath error:error];
                }
            } else {
                if (i < [components count] - 1) {
                    SETNSERROR([self errorDomain], -1, @"'%@' is not a directory", component);
                    return NO;
                }
                // Last component is a file — restore just this file.
                return [self restoreFile:childNode toPath:_destinationPath error:error];
            }
        }
    } else {
        // Create destination directory.
        NSFileManager *fm = [NSFileManager defaultManager];
        if (![fm createDirectoryAtPath:_destinationPath withIntermediateDirectories:YES attributes:nil error:error]) {
            return NO;
        }
    }

    return [self restoreTree:rootTree toPath:_destinationPath error:error];
}


#pragma mark internal

- (BOOL)restoreTree:(Arq7Tree *)theTree toPath:(NSString *)theDestPath error:(NSError **)error {
    NSFileManager *fm = [NSFileManager defaultManager];

    for (NSString *childName in [theTree childNodeNames]) {
        Arq7Node *childNode = [theTree childNodeWithName:childName];
        if ([childNode deleted]) {
            continue;
        }

        NSString *childPath = [theDestPath stringByAppendingPathComponent:childName];

        if ([childNode isTree]) {
            // Create directory.
            if (![fm createDirectoryAtPath:childPath withIntermediateDirectories:YES attributes:nil error:error]) {
                return NO;
            }
            // Recurse.
            Arq7Tree *childTree = [_blobReader treeForBlobLoc:childNode.treeBlobLoc error:error];
            if (childTree == nil) {
                return NO;
            }
            if (![self restoreTree:childTree toPath:childPath error:error]) {
                return NO;
            }
            // Apply directory metadata.
            if (![self applyMetadata:childNode toPath:childPath isDirectory:YES error:error]) {
                HSLogError(@"failed to apply metadata to %@: %@", childPath, error ? *error : nil);
                // Non-fatal: continue.
            }
        } else {
            // Write file.
            if (![self restoreFile:childNode toPath:childPath error:error]) {
                return NO;
            }
        }
    }
    return YES;
}

- (BOOL)restoreFile:(Arq7Node *)theNode toPath:(NSString *)thePath error:(NSError **)error {
    // Assemble file data from dataBlobLocs.
    NSFileManager *fm = [NSFileManager defaultManager];

    if (![fm createFileAtPath:thePath contents:nil attributes:nil]) {
        // File may already exist; open it for writing.
    }

    NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:thePath];
    if (fh == nil) {
        // Try creating it.
        if (![[NSData data] writeToFile:thePath options:0 error:error]) {
            return NO;
        }
        fh = [NSFileHandle fileHandleForWritingAtPath:thePath];
    }
    if (fh == nil) {
        SETNSERROR([self errorDomain], -1, @"failed to open %@ for writing", thePath);
        return NO;
    }

    BOOL success = YES;
    for (Arq7BlobLoc *blobLoc in [theNode dataBlobLocs]) {
        NSData *blobData = [_blobReader dataForBlobLoc:blobLoc error:error];
        if (blobData == nil) {
            success = NO;
            break;
        }
        [fh writeData:blobData];
    }
    [fh closeFile];

    if (!success) {
        return NO;
    }

    // Restore extended attributes.
    for (Arq7BlobLoc *xattrBlobLoc in [theNode xattrsBlobLocs]) {
        NSData *xattrData = [_blobReader dataForBlobLoc:xattrBlobLoc error:error];
        if (xattrData == nil) {
            HSLogError(@"failed to read xattr blob for %@", thePath);
            continue;
        }
        DataInputStream *dis = [[DataInputStream alloc] initWithData:xattrData description:@"xattrs"];
        BufferedInputStream *bis = [[BufferedInputStream alloc] initWithUnderlyingStream:dis];
        NSError *myError = nil;
        XAttrSet *xattrSet = [[XAttrSet alloc] initWithBufferedInputStream:bis error:&myError];
        if (xattrSet != nil) {
            [xattrSet applyToFile:thePath error:&myError];
        }
    }

    // Apply file metadata.
    if (![self applyMetadata:theNode toPath:thePath isDirectory:NO error:error]) {
        HSLogError(@"failed to apply metadata to %@", thePath);
        // Non-fatal.
    }

    printf("restored %s\n", [thePath UTF8String]);
    return YES;
}

- (BOOL)applyMetadata:(Arq7Node *)theNode toPath:(NSString *)thePath isDirectory:(BOOL)isDirectory error:(NSError **)error {
    // Apply Unix permissions.
    if (theNode.mac_st_mode != 0) {
        NSError *myError = nil;
        if (![FileAttributes applyMode:theNode.mac_st_mode toPath:thePath isDirectory:isDirectory error:&myError]) {
            HSLogError(@"applyMode failed for %@: %@", thePath, myError);
        }
    }

    // Apply UID/GID.
    if (theNode.mac_st_uid != 0 || theNode.mac_st_gid != 0) {
        NSError *myError = nil;
        if (![FileAttributes applyUID:theNode.mac_st_uid gid:theNode.mac_st_gid toPath:thePath error:&myError]) {
            HSLogError(@"applyUID:gid: failed for %@: %@", thePath, myError);
        }
    }

    // Apply flags.
    if (theNode.mac_st_flags != 0) {
        NSError *myError = nil;
        if (![FileAttributes applyFlags:theNode.mac_st_flags toPath:thePath error:&myError]) {
            HSLogError(@"applyFlags failed for %@: %@", thePath, myError);
        }
    }

    // Apply mtime.
    if (theNode.modificationTime_sec != 0) {
        NSError *myError = nil;
        if (![FileAttributes applyMTimeSec:theNode.modificationTime_sec
                                 mTimeNSec:theNode.modificationTime_nsec
                                    toPath:thePath
                                     error:&myError]) {
            HSLogError(@"applyMTimeSec failed for %@: %@", thePath, myError);
        }
    }

    return YES;
}
@end
