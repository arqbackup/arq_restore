/*
 Copyright (c) 2009-2017, Haystack Software LLC https://www.arqbackup.com
 
 All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 
 * Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in the
 documentation and/or other materials provided with the distribution.
 
 * Neither the names of PhotoMinds LLC or Haystack Software, nor the names of
 their contributors may be used to endorse or promote products derived from
 this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
 TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */



#include <unistd.h>
#include <sys/stat.h>
#import "LocalItemFS.h"
#import "Item.h"
#import "CacheOwnership.h"
#import "Streams.h"
#import "FSStat.h"
#import "Volume.h"
#import "MD5Hash.h"
#import "NSFileManager_extra.h"
#import "NSString_extra.h"


@implementation LocalItemFS

- (id)init {
    @throw [NSException exceptionWithName:@"WrongInitializerException" reason:@"wrong initializer called" userInfo:nil];
}
- (id)initWithEndpoint:(NSURL *)theEndpoint error:(NSError **)error {
    if (self = [super init]) {
        NSError *myError = nil;
        NSArray *names = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[theEndpoint path] error:&myError];
        if (names == nil) {
            SETNSERROR([self errorDomain], -1, @"Failed to initialize endpoint %@: %@", [theEndpoint path], [myError localizedDescription]);
            [self release];
            return nil;
        }
        
        FSStat *fsStat = [[[FSStat alloc] init] autorelease];
        Volume *volume = [fsStat volumeForPath:[theEndpoint path] error:error];
        if (volume == nil) {
            [self release];
            return nil;
        }
        volumeIsRemote = [volume isRemote];
        
        NSString *pathPrefix = [theEndpoint path];
        if ([pathPrefix isEqualToString:@"/"]) {
            pathPrefix = @"";
        }
        tempDir = [[NSString alloc] initWithFormat:@"%@/temp", pathPrefix];
    }
    return self;
}
- (void)dealloc {
    [tempDir release];
    [super dealloc];
}


- (NSString *)errorDomain {
    return @"LocalItemFSErrorDomain";
}


#pragma mark ItemFS
- (NSString *)itemFSDescription {
    return @"local";
}
- (BOOL)canRemoveDirectoriesAtomically {
    return YES;
}
- (BOOL)usesFolderIds {
    return NO;
}
- (BOOL)enforcesUniqueFilenames {
    return YES;
}
- (Item *)rootDirectoryItemWithTargetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD error:(NSError **)error {
    Item *item = [[[Item alloc] init] autorelease];
    item.name = @"/";
    item.isDirectory = YES;
    return item;
}
- (NSDictionary *)itemsByNameInDirectoryItem:(Item *)theItem path:(NSString *)theDirectoryPath targetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD duplicatesWereMerged:(BOOL *)duplicatesWereMerged error:(NSError **)error {
    *duplicatesWereMerged = NO;
    NSString *localPath = theDirectoryPath; //[path stringByAppendingString:theDirectoryPath];
    NSMutableDictionary *ret = [NSMutableDictionary dictionary];
    
    BOOL isDir = NO;
    if ([[NSFileManager defaultManager] fileExistsAtPath:localPath isDirectory:&isDir]) {
        if (!isDir) {
            SETNSERROR([self errorDomain], -1, @"%@ exists and is not a directory", localPath);
            return nil;
        }
        NSArray *names = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:localPath error:error];
        if (names == nil) {
            return nil;
        }
        for (NSString *name in names) {
            NSString *childPath = [localPath stringByAppendingPathComponent:name];
            NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:childPath error:error];
            if (attrs == nil) {
                return nil;
            }
            Item *item = [[[Item alloc] init] autorelease];
            item.name = name;
            item.isDirectory = [[attrs fileType] isEqualToString:NSFileTypeDirectory];
            if (!item.isDirectory) {
                item.fileSize = [attrs fileSize];
                item.fileLastModified = [attrs fileModificationDate];
            }
            [ret setObject:item forKey:name];
        }
    }
    return ret;
}
- (Item *)createDirectoryWithName:(NSString *)theName inDirectoryItem:(Item *)theDirectoryItem itemPath:(NSString *)thePath targetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD error:(NSError **)error {
    NSString *localPath = thePath; //[path stringByAppendingString:theDirectoryPath];
    NSError *myError = nil;
    NSDictionary *attrs = [NSDictionary dictionaryWithObject:[NSNumber numberWithShort:0775] forKey:NSFilePosixPermissions];
    if (![[NSFileManager defaultManager] createDirectoryAtPath:localPath withIntermediateDirectories:YES attributes:attrs error:&myError]) {
        if (![myError isErrorWithDomain:NSCocoaErrorDomain code:NSFileWriteFileExistsError]) {
            SETERRORFROMMYERROR;
            return nil;
        }
        HSLogDebug(@"%@ already exists", localPath);
    }
    
    if (!volumeIsRemote && (
                            ([[CacheOwnership sharedCacheOwnership] uid] != getuid())
                            || ([[CacheOwnership sharedCacheOwnership] gid] != getgid())
                            )
        ) {
        // Set the UID/GID of the file.
        if (chown([thePath fileSystemRepresentation], [[CacheOwnership sharedCacheOwnership] uid], [[CacheOwnership sharedCacheOwnership] gid]) < 0) {
            int errnum = errno;
            HSLogError(@"chown(%@) error %d: %s", thePath, errnum, strerror(errnum));
            SETNSERROR(@"UnixErrorDomain", errnum, @"failed to change ownership of %@: %s", thePath, strerror(errnum));
            return nil;
        }
    }
    
    Item *ret = [[[Item alloc] init] autorelease];
    ret.name = theName;
    ret.isDirectory = YES;
    return ret;
}
- (BOOL)removeDirectoryItem:(Item *)theItem inDirectoryItem:(Item *)theParentDirectoryItem itemPath:(NSString *)thePath targetConnectionDelegate:(id<TargetConnectionDelegate>)theTCD error:(NSError **)error {
    NSString *localPath = thePath; //[path stringByAppendingString:theDirectoryPath];
    return [[NSFileManager defaultManager] removeItemAtPath:localPath error:error];
}
- (NSData *)contentsOfRange:(NSRange)theRange ofFileItem:(Item *)theItem itemPath:(NSString *)theFullPath dataTransferDelegate:(id <DataTransferDelegate>)theDTD targetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD error:(NSError **)error {
    NSString *localPath = theFullPath; //[path stringByAppendingString:theDirectoryPath];
    NSError *myError = nil;
    NSData *ret = [NSData dataWithContentsOfFile:localPath options:NSUncachedRead error:&myError];
    if (ret == nil) {
        if ([myError isErrorWithDomain:NSCocoaErrorDomain code:NSFileReadNoSuchFileError]) {
            myError = [[[NSError alloc] initWithDomain:[self errorDomain] code:ERROR_NOT_FOUND description:[NSString stringWithFormat:@"%@ not found", theFullPath]] autorelease];
        }
        SETERRORFROMMYERROR;
    }
    if (theRange.location != NSNotFound) {
        if ([ret length] < (theRange.location + theRange.length)) {
            SETNSERROR([self errorDomain], -1, @"requested bytes at %ld length %ld but got %ld bytes", theRange.location, theRange.length, [ret length]);
            return nil;
        }
        ret = [ret subdataWithRange:theRange];
    }
    return ret;
}
- (Item *)createFileWithData:(NSData *)theData name:(NSString *)theName inDirectoryItem:(Item *)theDirectoryItem existingItem:(Item *)theExistingItem itemPath:(NSString *)theFullPath dataTransferDelegate:(id <DataTransferDelegate>)theDTD targetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD error:(NSError **)error {
    HSLogDebug(@"creating %@", theFullPath);
    
    NSError *myError = nil;
    if (![self ensureTempDirExists:&myError]) {
        SETERRORFROMMYERROR;
        HSLogError(@"error ensuring temp dir %@ exists: %@", tempDir, myError);
        return nil;
    }
    
    NSString *tempPath = [tempDir stringByAppendingPathComponent:[NSString stringWithRandomUUID]];
    if (![theData writeToFile:tempPath options:NSAtomicWrite error:&myError]) {
        SETERRORFROMMYERROR;
        HSLogError(@"error creating temp file %@: %@", tempPath, myError);
        return nil;
    }
    
    if (![[NSFileManager defaultManager] ensureParentPathExistsForPath:theFullPath targetUID:[[CacheOwnership sharedCacheOwnership] uid] targetGID:[[CacheOwnership sharedCacheOwnership] gid] error:error]) {
        return nil;
    }
    if (![[NSFileManager defaultManager] moveItemAtPath:tempPath toPath:theFullPath error:&myError]) {
        if (![myError isErrorWithDomain:NSCocoaErrorDomain code:NSFileWriteFileExistsError]) {
            SETERRORFROMMYERROR;
            HSLogError(@"error renaming %@ to %@: %@", tempPath, theFullPath, myError);
            return nil;
        }
        // Delete the file that's in the way.
        HSLogDebug(@"deleting existing file before overwriting: %@", theFullPath);
        if (![[NSFileManager defaultManager] removeItemAtPath:theFullPath error:&myError]) {
            SETERRORFROMMYERROR;
            HSLogError(@"error removing a file that's in the way (%@): %@", theFullPath, myError);
            return nil;
        }
        // Try again.
        if (![[NSFileManager defaultManager] moveItemAtPath:tempPath toPath:theFullPath error:&myError]) {
            if (![myError isErrorWithDomain:NSCocoaErrorDomain code:NSFileWriteFileExistsError]) {
                SETERRORFROMMYERROR;
                HSLogError(@"error renaming %@ to %@: %@", tempPath, theFullPath, myError);
                return nil;
            }
        }
    }
    
    if (!volumeIsRemote && (
                            ([[CacheOwnership sharedCacheOwnership] uid] != getuid())
                            || ([[CacheOwnership sharedCacheOwnership] gid] != getgid())
                            )
        ) {
        // Set the UID/GID of the file.
        if (chown([theFullPath fileSystemRepresentation], [[CacheOwnership sharedCacheOwnership] uid], [[CacheOwnership sharedCacheOwnership] gid]) < 0) {
            int errnum = errno;
            HSLogError(@"chown(%@) error %d: %s", theFullPath, errnum, strerror(errnum));
            SETNSERROR(@"UnixErrorDomain", errnum, @"failed to change ownership of %@: %s", theFullPath, strerror(errnum));
            return nil;
        }
    }
    Item *item = [[[Item alloc] init] autorelease];
    item.name = theName;
    item.isDirectory = NO;
    item.fileSize = [theData length];
    item.fileLastModified = [NSDate date];
    item.checksum = [@"md5:" stringByAppendingString:[MD5Hash hashData:theData]];
    return item;
}
- (BOOL)moveItem:(Item *)theItem toNewName:(NSString *)theNewName fromDirectoryItem:(Item *)theFromDirectoryItem fromDirectory:(NSString *)theFromDir toDirectoryItem:(Item *)theToDirectoryItem toDirectory:(NSString *)theToDir targetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD error:(NSError **)error {
    NSString *theSource = [theFromDir stringByAppendingPathComponent:theItem.name];
    NSString *theDest = [theToDir stringByAppendingPathComponent:theNewName];
    
    NSString *theSourceLocalPath = theSource; // [path stringByAppendingString:theSource];
    NSString *theDestLocalPath = theDest; // [path stringByAppendingString:theDest];
    
    return [[NSFileManager defaultManager] moveItemAtPath:theSourceLocalPath toPath:theDestLocalPath error:error];
}
- (BOOL)removeFileItem:(Item *)theItem itemPath:(NSString *)theFullPath targetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD error:(NSError **)error {
    if ([theFullPath isEqualToString:@"/"]) {
        return [[NSFileManager defaultManager] removeItemAtPath:theFullPath error:error];
    }
    
    NSString *localPath = theFullPath; // [path stringByAppendingString:theFullPath];
    return [[NSFileManager defaultManager] removeItemAtPath:localPath error:error];
}
- (NSNumber *)freeBytesAtPath:(NSString *)thePath targetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD error:(NSError **)error {
    NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfFileSystemForPath:thePath error:error];
    if (attrs == nil) {
        return nil;
    }
    return [attrs objectForKey:NSFileSystemFreeSize];
}
- (BOOL)updateFingerprintWithTargetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD error:(NSError **)error {
    return YES;
}
- (NSNumber *)isObjectRestoredAtPath:(NSString *)thePath targetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD error:(NSError **)error {
    return [NSNumber numberWithBool:YES];
}
- (BOOL)restoreObjectAtPath:(NSString *)thePath forDays:(NSUInteger)theDays tier:(int)theGlacierRetrievalTier alreadyRestoredOrRestoring:(BOOL *)alreadyRestoredOrRestoring targetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD error:(NSError **)error {
    return YES;
}
- (BOOL)removeItemById:(NSString *)theItemId targetConnectionDelegate:(id<TargetConnectionDelegate>)theTCD error:(NSError **)error {
    SETNSERROR([self errorDomain], -1, @"removeItemById not implemented");
    return NO;
}


- (BOOL)ensureTempDirExists:(NSError **)error {
    if (!tempDirExists) {
        BOOL isDir = NO;
        if ([[NSFileManager defaultManager] fileExistsAtPath:tempDir isDirectory:&isDir]) {
            if (!isDir) {
                SETNSERROR([self errorDomain], -1, @"temp path %@ exists and is not a directory", tempDir);
                return NO;
            }
        } else {
            Item *existingTempDir = [self createDirectoryWithName:tempDir inDirectoryItem:nil itemPath:tempDir targetConnectionDelegate:nil error:error];
            if (existingTempDir == nil) {
                return NO;
            }
        }
        tempDirExists = YES;
    }
    return YES;
}
@end
