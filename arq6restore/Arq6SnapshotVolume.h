/*
 Arq6SnapshotVolume — one backed-up volume within an Arq 6 snapshot.
*/

#import <Foundation/Foundation.h>
@class Arq7Node;

@interface Arq6SnapshotVolume : NSObject

@property (readonly) NSString *diskIdentifier;
@property (readonly) NSString *name;
@property (readonly) NSString *mountPoint;
@property (readonly) Arq7Node *node;

- (instancetype)initWithDiskIdentifier:(NSString *)theDiskIdentifier
                                  name:(NSString *)theName
                            mountPoint:(NSString *)theMountPoint
                                  node:(Arq7Node *)theNode;
@end
