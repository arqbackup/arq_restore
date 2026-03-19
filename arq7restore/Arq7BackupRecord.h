/*
 Arq7BackupRecord — reads and parses a single .backuprecord file from an Arq 7 backup.
 File format: [optional ARQO encryption] + [LZ4 compression] + JSON.
*/

@class Arq7Node;
@class Arq7KeySet;
@class TargetConnection;
@protocol TargetConnectionDelegate;

@interface Arq7BackupRecord : NSObject

@property (readonly) int version;           // 100 = native Arq7, 12 = Arq5-compat
@property (readonly) NSString *localPath;
@property (readonly) NSString *backupFolderUUID;
@property (readonly) NSString *backupPlanUUID;
@property (readonly) NSDate *creationDate;
@property (readonly) BOOL isComplete;
@property (readonly) Arq7Node *node;        // set for version 100 records

// Returns the most recent complete backup record for the given folder.
// keySet may be nil if backup set is not encrypted.
+ (Arq7BackupRecord *)mostRecentBackupRecordForPlanUUID:(NSString *)thePlanUUID
                                             folderUUID:(NSString *)theFolderUUID
                                       targetConnection:(TargetConnection *)theConn
                                                 keySet:(Arq7KeySet *)theKeySet
                                               delegate:(id <TargetConnectionDelegate>)theDelegate
                                                  error:(NSError **)error;
@end
