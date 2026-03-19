/*
 Arq7BackupSet — represents an Arq 7 backup plan (identified by planUUID).
 Reads <planUUID>/backupconfig.json via TargetConnection.
 Detection: if backupconfig.json exists at <uuid>/ it's an Arq7 backup set.
*/

@class Target;
@class TargetConnection;
@protocol TargetConnectionDelegate;

@interface Arq7BackupSet : NSObject

@property (readonly) NSString *planUUID;
@property (readonly) NSString *backupName;
@property (readonly) NSString *computerName;
@property (readonly) BOOL isEncrypted;
@property (readonly) int blobIdentifierType; // 1=SHA1, 2=SHA256

// Lists all Arq7 backup sets found at the given target.
+ (NSArray *)allBackupSetsForTarget:(Target *)theTarget
                           delegate:(id <TargetConnectionDelegate>)theDelegate
                              error:(NSError **)error;

// Reads a single backup set given a planUUID.
+ (Arq7BackupSet *)backupSetWithPlanUUID:(NSString *)thePlanUUID
                        targetConnection:(TargetConnection *)theConn
                                delegate:(id <TargetConnectionDelegate>)theDelegate
                                   error:(NSError **)error;
@end
