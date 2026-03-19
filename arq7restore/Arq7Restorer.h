/*
 Arq7Restorer — orchestrates the restore of an Arq 7 backup folder to a local destination.
*/

@class Arq7KeySet;
@class TargetConnection;
@protocol TargetConnectionDelegate;

@interface Arq7Restorer : NSObject

- (instancetype)initWithPlanUUID:(NSString *)thePlanUUID
                      folderUUID:(NSString *)theFolderUUID
                targetConnection:(TargetConnection *)theConn
                          keySet:(Arq7KeySet *)theKeySet
                    relativePath:(NSString *)theRelativePath
                 destinationPath:(NSString *)theDestinationPath
                        delegate:(id <TargetConnectionDelegate>)theDelegate;

// Runs the restore synchronously. Returns NO on error.
- (BOOL)restore:(NSError **)error;
@end
