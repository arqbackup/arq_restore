/*
 Arq7BackupFolder — represents a single backup folder within an Arq 7 backup plan.
 Reads <planUUID>/backupfolders/<folderUUID>/backupfolder.json via TargetConnection.
*/

@class TargetConnection;
@protocol TargetConnectionDelegate;

@interface Arq7BackupFolder : NSObject

@property (readonly) NSString *folderUUID;
@property (readonly) NSString *localPath;
@property (readonly) NSString *name;
@property (readonly) NSString *storageClass;

// Lists all backup folders for the given plan UUID.
+ (NSArray *)backupFoldersForPlanUUID:(NSString *)thePlanUUID
                     targetConnection:(TargetConnection *)theConn
                             delegate:(id <TargetConnectionDelegate>)theDelegate
                                error:(NSError **)error;
@end
