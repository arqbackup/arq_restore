#import "Arq7BackupFolder.h"
#import "TargetConnection.h"
#import "Item.h"


@interface Arq7BackupFolder() {
    NSString *_folderUUID;
    NSString *_localPath;
    NSString *_name;
    NSString *_storageClass;
}
@end


@implementation Arq7BackupFolder

- (NSString *)errorDomain {
    return @"Arq7BackupFolderErrorDomain";
}

+ (NSArray *)backupFoldersForPlanUUID:(NSString *)thePlanUUID
                     targetConnection:(TargetConnection *)theConn
                             delegate:(id <TargetConnectionDelegate>)theDelegate
                                error:(NSError **)error {
    NSString *foldersPath = [NSString stringWithFormat:@"/%@/backupfolders", thePlanUUID];
    NSDictionary *itemsByName = [theConn itemsByNameAtPath:foldersPath targetConnectionDelegate:theDelegate error:error];
    if (itemsByName == nil) {
        return nil;
    }

    NSMutableArray *ret = [NSMutableArray array];
    for (NSString *folderUUID in [itemsByName allKeys]) {
        if ([folderUUID isEqualToString:@".DS_Store"] || [folderUUID isEqualToString:@"@eaDir"]) {
            continue;
        }
        Item *item = [itemsByName objectForKey:folderUUID];
        if (![item isDirectory]) {
            continue;
        }

        NSString *jsonPath = [NSString stringWithFormat:@"/%@/backupfolders/%@/backupfolder.json", thePlanUUID, folderUUID];
        NSError *myError = nil;
        NSData *jsonData = [theConn contentsOfFileAtPath:jsonPath delegate:theDelegate error:&myError];
        if (jsonData == nil) {
            HSLogError(@"failed to read %@: %@", jsonPath, myError);
            continue;
        }

        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:error];
        if (json == nil) {
            return nil;
        }

        Arq7BackupFolder *folder = [[Arq7BackupFolder alloc] initWithFolderUUID:folderUUID json:json];
        [ret addObject:folder];
    }
    return ret;
}

- (instancetype)initWithFolderUUID:(NSString *)theFolderUUID json:(NSDictionary *)theJSON {
    if (self = [super init]) {
        _folderUUID = theFolderUUID;
        _localPath = [theJSON objectForKey:@"localPath"];
        _name = [theJSON objectForKey:@"name"];
        _storageClass = [theJSON objectForKey:@"storageClass"];
    }
    return self;
}

- (NSString *)folderUUID { return _folderUUID; }
- (NSString *)localPath { return _localPath; }
- (NSString *)name { return _name; }
- (NSString *)storageClass { return _storageClass; }
@end
