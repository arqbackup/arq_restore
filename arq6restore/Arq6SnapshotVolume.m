#import "Arq6SnapshotVolume.h"
#import "Arq7Node.h"


@interface Arq6SnapshotVolume() {
    NSString *_diskIdentifier;
    NSString *_name;
    NSString *_mountPoint;
    Arq7Node *_node;
}
@end


@implementation Arq6SnapshotVolume

- (instancetype)initWithDiskIdentifier:(NSString *)theDiskIdentifier
                                  name:(NSString *)theName
                            mountPoint:(NSString *)theMountPoint
                                  node:(Arq7Node *)theNode {
    if (self = [super init]) {
        _diskIdentifier = theDiskIdentifier;
        _name = theName;
        _mountPoint = theMountPoint;
        _node = theNode;
    }
    return self;
}

- (NSString *)diskIdentifier { return _diskIdentifier; }
- (NSString *)name { return _name; }
- (NSString *)mountPoint { return _mountPoint; }
- (Arq7Node *)node { return _node; }
@end
