#import "Arq7BackupSet.h"
#import "Target.h"
#import "TargetConnection.h"


@interface Arq7BackupSet() {
    NSString *_planUUID;
    NSString *_backupName;
    NSString *_computerName;
    BOOL _isEncrypted;
    int _blobIdentifierType;
}
@end


@implementation Arq7BackupSet

- (NSString *)errorDomain {
    return @"Arq7BackupSetErrorDomain";
}

+ (NSArray *)allBackupSetsForTarget:(Target *)theTarget
                           delegate:(id <TargetConnectionDelegate>)theDelegate
                              error:(NSError **)error {
    TargetConnection *conn = [theTarget newConnection:error];
    if (conn == nil) {
        return nil;
    }

    // computerUUIDsWithDelegate: lists root-level UUIDs.
    NSArray *uuids = [conn computerUUIDsWithDelegate:theDelegate error:error];
    if (uuids == nil) {
        return nil;
    }

    NSMutableArray *ret = [NSMutableArray array];
    for (NSString *uuid in uuids) {
        NSError *myError = nil;
        Arq7BackupSet *bs = [Arq7BackupSet backupSetWithPlanUUID:uuid targetConnection:conn delegate:theDelegate error:&myError];
        if (bs != nil) {
            [ret addObject:bs];
        }
        // If nil, it's not an Arq7 backup set (e.g., it's an Arq5 computerUUID) — skip silently.
    }
    return ret;
}

+ (Arq7BackupSet *)backupSetWithPlanUUID:(NSString *)thePlanUUID
                        targetConnection:(TargetConnection *)theConn
                                delegate:(id <TargetConnectionDelegate>)theDelegate
                                   error:(NSError **)error {
    NSString *configPath = [NSString stringWithFormat:@"%@/%@/backupconfig.json", [theConn pathPrefix], thePlanUUID];
    NSError *myError = nil;
    NSNumber *exists = [theConn fileExistsAtPath:configPath dataSize:NULL delegate:theDelegate error:&myError];
    if (exists == nil || ![exists boolValue]) {
        // Not an Arq7 backup set.
        return nil;
    }

    NSData *jsonData = [theConn contentsOfFileAtPath:configPath delegate:theDelegate error:error];
    if (jsonData == nil) {
        return nil;
    }

    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:error];
    if (json == nil) {
        return nil;
    }

    Arq7BackupSet *bs = [[Arq7BackupSet alloc] initWithPlanUUID:thePlanUUID json:json];
    return bs;
}

- (instancetype)initWithPlanUUID:(NSString *)thePlanUUID json:(NSDictionary *)theJSON {
    if (self = [super init]) {
        _planUUID = thePlanUUID;
        _backupName = [theJSON objectForKey:@"backupName"];
        _computerName = [theJSON objectForKey:@"computerName"];
        _isEncrypted = [[theJSON objectForKey:@"isEncrypted"] boolValue];
        _blobIdentifierType = [[theJSON objectForKey:@"blobIdentifierType"] intValue];
    }
    return self;
}

- (NSString *)planUUID { return _planUUID; }
- (NSString *)backupName { return _backupName; }
- (NSString *)computerName { return _computerName; }
- (BOOL)isEncrypted { return _isEncrypted; }
- (int)blobIdentifierType { return _blobIdentifierType; }
@end
