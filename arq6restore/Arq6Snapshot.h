/*
 Arq6Snapshot — reads and parses a single .snapshot file from an Arq 6 backup.
 File format: [optional ARQO encryption] + [LZ4 compression] + JSON.
*/

#import <Foundation/Foundation.h>
@class Arq6SnapshotVolume;
@class Arq7KeySet;
@class TargetConnection;
@protocol TargetConnectionDelegate;

@interface Arq6Snapshot : NSObject

@property (readonly) NSDate *creationDate;
@property (readonly) BOOL isComplete;
@property (readonly) NSString *planUUID;
@property (readonly) NSDictionary *volumesByDiskIdentifier; // NSString -> Arq6SnapshotVolume

// Returns YES if the given plan UUID has a snapshots/ directory (indicating Arq 6 format).
// Errors are silently suppressed; returns NO on any failure.
+ (BOOL)isArq6PlanUUID:(NSString *)thePlanUUID
      targetConnection:(TargetConnection *)theConn
              delegate:(id <TargetConnectionDelegate>)theDelegate;

// Returns the most recent complete snapshot for the given plan UUID.
// keySet may be nil if the backup set is not encrypted.
+ (Arq6Snapshot *)mostRecentSnapshotForPlanUUID:(NSString *)thePlanUUID
                                targetConnection:(TargetConnection *)theConn
                                          keySet:(Arq7KeySet *)theKeySet
                                        delegate:(id <TargetConnectionDelegate>)theDelegate
                                           error:(NSError **)error;
@end
