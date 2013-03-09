//
//  BlobKeyIO.m
//
//  Created by Stefan Reitshamer on 9/14/12.
//
//

#import "BlobKeyIO.h"
#import "BooleanIO.h"
#import "StringIO.h"
#import "IntegerIO.h"
#import "StorageType.h"
#import "BlobKey.h"
#import "DateIO.h"


@implementation BlobKeyIO
+ (void)write:(BlobKey *)theBlobKey to:(NSMutableData *)data {
    [StringIO write:[theBlobKey sha1] to:data];
    [BooleanIO write:[theBlobKey stretchEncryptionKey] to:data];
    [IntegerIO writeUInt32:(uint32_t)[theBlobKey storageType] to:data];
    [StringIO write:[theBlobKey archiveId] to:data];
    [IntegerIO writeUInt64:[theBlobKey archiveSize] to:data];
    [DateIO write:[theBlobKey archiveUploadedDate] to:data];
}
+ (BOOL)read:(BlobKey **)theBlobKey from:(BufferedInputStream *)is treeVersion:(int)theTreeVersion compressed:(BOOL)isCompressed error:(NSError **)error {
    NSString *dataSHA1;
    BOOL stretchEncryptionKey = NO;
    StorageType storageType = StorageTypeS3;
    NSString *archiveId = nil;
    uint64_t archiveSize = 0;
    NSDate *archiveUploadedDate = nil;
    
    if (![StringIO read:&dataSHA1 from:is error:error]) {
        [self release];
        return NO;
    }
    if (theTreeVersion >= 14 && ![BooleanIO read:&stretchEncryptionKey from:is error:error]) {
        [self release];
        return NO;
    }
    if (theTreeVersion >= 17) {
        if (![IntegerIO readUInt32:&storageType from:is error:error]
            || ![StringIO read:&archiveId from:is error:error]
            || ![IntegerIO readUInt64:&archiveSize from:is error:error]
            || ![DateIO read:&archiveUploadedDate from:is error:error]) {
            [self release];
            return NO;
        }
    }
    *theBlobKey = [[[BlobKey alloc] initWithStorageType:storageType archiveId:archiveId archiveSize:archiveSize archiveUploadedDate:archiveUploadedDate sha1:dataSHA1 stretchEncryptionKey:stretchEncryptionKey compressed:isCompressed] autorelease];
    return YES;
}
@end
