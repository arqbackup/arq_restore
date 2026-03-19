/*
 Arq6Restorer — orchestrates the restore of an Arq 6 backup volume to a local destination.
*/

#import <Foundation/Foundation.h>
@class Arq7KeySet;
@class TargetConnection;
@protocol TargetConnectionDelegate;

@interface Arq6Restorer : NSObject

- (instancetype)initWithPlanUUID:(NSString *)thePlanUUID
                  diskIdentifier:(NSString *)theDiskIdentifier
                targetConnection:(TargetConnection *)theConn
                          keySet:(Arq7KeySet *)theKeySet
                    relativePath:(NSString *)theRelativePath
                 destinationPath:(NSString *)theDestinationPath
                        delegate:(id <TargetConnectionDelegate>)theDelegate;

// Runs the restore synchronously. Returns NO on error.
- (BOOL)restore:(NSError **)error;
@end
