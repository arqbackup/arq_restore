#import "Arq7BackupFolder.h"
#import "Arq7KeySet.h"
#import "Arq7EncryptedObjectDecryptor.h"
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
                               keySet:(Arq7KeySet *)theKeySet
                             delegate:(id <TargetConnectionDelegate>)theDelegate
                                error:(NSError **)error {
    NSString *foldersPath = [NSString stringWithFormat:@"%@/%@/backupfolders", [theConn pathPrefix], thePlanUUID];
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

        NSString *jsonPath = [NSString stringWithFormat:@"%@/%@/backupfolders/%@/backupfolder.json", [theConn pathPrefix], thePlanUUID, folderUUID];
        NSError *myError = nil;
        NSData *data = [theConn contentsOfFileAtPath:jsonPath delegate:theDelegate error:&myError];
        if (data == nil) {
            HSLogError(@"failed to read %@: %@", jsonPath, myError);
            continue;
        }

        // Decrypt if ARQO-prefixed.
        if ([Arq7EncryptedObjectDecryptor isEncryptedData:data]) {
            if (theKeySet == nil) {
                SETNSERROR(@"Arq7BackupFolderErrorDomain", ERROR_INVALID_PASSWORD, @"backupfolder.json is encrypted but no key set provided");
                return nil;
            }
            Arq7EncryptedObjectDecryptor *dec = [[Arq7EncryptedObjectDecryptor alloc] initWithKeySet:theKeySet];
            data = [dec decryptData:data error:error];
            if (data == nil) {
                return nil;
            }
        }

        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:error];
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
