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



#import "TargetFactory.h"
#import "DictNode.h"
#import "StringNode.h"
#import "Target.h"
#import "UserLibrary_Arq.h"
#import "NSFileManager_extra.h"
#import "KeychainFactory.h"
#import "Keychain.h"
#import "KeychainItem.h"
#import "Streams.h"
#import "CacheOwnership.h"


@interface TargetFactory ()
- (void)targetFilesChanged;
@end


static void fsEventStreamCallback(ConstFSEventStreamRef streamRef,
								  void *clientCallBackInfo,
								  size_t numEvents,
								  const char *const eventPaths[],
								  const FSEventStreamEventFlags eventFlags[],
								  const FSEventStreamEventId eventIds[]) {
    TargetFactory *targetFactory = (TargetFactory *)clientCallBackInfo;
    [targetFactory targetFilesChanged];
}




@implementation TargetFactory
CWL_SYNTHESIZE_SINGLETON_FOR_CLASS(TargetFactory);

- (id)init {
    if (self = [super init]) {
        changeListeners = [[NSMutableSet alloc] init];
        [self monitorForChanges];

        sortedTargets = [[NSMutableArray alloc] init];
        NSError *myError = nil;
        NSArray *theTargets = [self sortedTargets:&myError];
        if (theTargets == nil) {
            HSLogError(@"failed to load targets: %@", myError);
        } else {
            [sortedTargets setArray:theTargets];
        }
    }
    return self;
}
- (BOOL)deleteAllTargets:(NSError **)error {
    for (Target *target in sortedTargets) {
        if (![self doDeleteTarget:target error:error]) {
            return NO;
        }
    }
    return YES;
}
- (NSArray *)sortedTargets {
    return [NSArray arrayWithArray:sortedTargets];
}
- (Target *)targetWithNickname:(NSString *)theTargetNickname {
    for (Target *target in sortedTargets) {
        if ([[target nickname] isEqualToString:theTargetNickname]) {
            return target;
        }
    }
    return nil;
}
- (Target *)targetWithUUID:(NSString *)theTargetUUID {
    for (Target *target in sortedTargets) {
        if ([[target targetUUID] isEqualToString:theTargetUUID]) {
            return target;
        }
    }
    return nil;
}
- (BOOL)saveTarget:(Target *)theTarget error:(NSError **)error {
    if (![[NSFileManager defaultManager] createDirectoryAtPath:[self targetsDir] withIntermediateDirectories:YES attributes:nil error:error]) {
        return NO;
    }
    DictNode *plist = [theTarget toPlist];
    NSData *xmlData = [plist XMLData];

    HSLogDebug(@"writing XML data for target %@ to %@", [theTarget targetUUID], [self pathForTarget:theTarget]);
    
    if (![Streams writeData:xmlData atomicallyToFile:[self pathForTarget:theTarget] targetUID:[[CacheOwnership sharedCacheOwnership] uid] targetGID:[[CacheOwnership sharedCacheOwnership] gid] bytesWritten:NULL error:error]) {
        return NO;
    }
    
    [self refresh];
    
    return YES;
}
- (BOOL)replaceTarget:(Target *)theOldTarget withTarget:(Target *)theNewTarget error:(NSError **)error {
    if (![self doDeleteTarget:theOldTarget error:error]) {
        return NO;
    }
    return [self saveTarget:theNewTarget error:error];
}
- (BOOL)deleteTarget:(Target *)theTarget error:(NSError **)error {
    if (![self doDeleteTarget:theTarget error:error]) {
        return NO;
    }
    [self refresh];
    
    return YES;
}
- (void)refresh {
    [self targetFilesChanged];
}

- (void)addChangeListener:(id)listener {
    [changeListeners addObject:listener];
}
- (void)removeChangeListener:(id<TargetFactoryChangeListener>)listener {
    [changeListeners removeObject:listener];
}

- (void)monitorForChanges {
    CFAbsoluteTime latency = 1.0; // seconds
    FSEventStreamContext context = {
        0,
        self,
        NULL,
        NULL,
        NULL
    };
    NSArray *pathsToWatch = [NSArray arrayWithObject:[self targetsDir]];
    streamRef = FSEventStreamCreate(NULL,
                                    (FSEventStreamCallback)&fsEventStreamCallback,
                                    &context,
                                    (CFArrayRef)pathsToWatch,
                                    kFSEventStreamEventIdSinceNow,
                                    latency,
                                    kFSEventStreamCreateFlagNoDefer
                                    );
    FSEventStreamScheduleWithRunLoop(streamRef, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
    FSEventStreamStart(streamRef);
}


#pragma mark internal

- (NSString *)errorDomain {
    return @"TargetFactoryErrorDomain";
}
- (BOOL)doDeleteTarget:(Target *)theTarget error:(NSError **)error {
    HSLogDebug(@"deleting XML data for target %@: %@", [theTarget targetUUID], [self pathForTarget:theTarget]);
    
    if (![[NSFileManager defaultManager] removeItemAtPath:[self pathForTarget:theTarget] error:error]) {
        return NO;
    }
    NSError *myError = nil;
    if (![theTarget deleteSecret:&myError]) {
        HSLogError(@"error deleting secret for %@: %@", theTarget, myError);
    }
    if (![theTarget deletePassphrase:&myError]) {
        HSLogError(@"error deleting passphrase for %@: %@", theTarget, myError);
    }
    if (![theTarget deleteOAuth2ClientSecret:&myError]) {
        HSLogError(@"error deleting secret for %@: %@", theTarget, myError);
    }
    
    NSString *cachePath = [[UserLibrary arqCachePath] stringByAppendingPathComponent:[theTarget targetUUID]];
    if (![[NSFileManager defaultManager] removeItemAtPath:cachePath error:&myError]) {
        HSLogError(@"error deleting cache for target %@: %@", theTarget, myError);
    }
    
    return YES;
}
- (NSArray *)sortedTargets:(NSError **)error {
    NSMutableArray *ret = [NSMutableArray array];
    if ([[NSFileManager defaultManager] fileExistsAtPath:[self targetsDir]]) {
        NSArray *targetFileNames = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[self targetsDir] error:error];
        if (targetFileNames == nil) {
            return nil;
        } else {
            for (NSString *targetFile in targetFileNames) {
                NSString *targetPath = [[self targetsDir] stringByAppendingPathComponent:targetFile];
                NSError *myError = nil;
                Target *target = [self targetWithPlistPath:targetPath error:&myError];
                if (target == nil) {
                    HSLogError(@"failed to parse target file %@: %@", targetFile, myError);
                } else {
                    
                    HSLogDebug(@"loaded target %@ from %@", [target targetUUID], targetPath);
                    
                    [ret addObject:target];
                }
            }
        }
    }
    NSSortDescriptor *descriptor = [[[NSSortDescriptor alloc] initWithKey:@"targetUUID" ascending:YES] autorelease];
    [ret sortUsingDescriptors:[NSArray arrayWithObject:descriptor]];
    return ret;
}
- (Target *)targetWithPlistPath:(NSString *)thePath error:(NSError **)error {
    NSData *data = [[NSData alloc] initWithContentsOfFile:thePath options:0 error:error];
    if (!data) {
        return nil;
    }
    NSError *myError = nil;
    DictNode *plist = [DictNode dictNodeWithXMLData:data error:&myError];
    [data release];
    if (plist == nil) {
        SETNSERROR([self errorDomain], -1, @"error parsing %@: %@", thePath, [myError localizedDescription]);
        return nil;
    }
    NSString *targetType = [[plist stringNodeForKey:@"targetType"] stringValue];
    if ([targetType isEqualToString:@"s3"]) {
        return [[[Target alloc] initWithPlist:plist] autorelease];
    }
    SETNSERROR([self errorDomain], -1, @"unknown target type '%@'", targetType);
    return nil;
}
- (NSString *)targetsDir {
    return [[[UserLibrary arqUserLibraryPath] stringByAppendingPathComponent:@"config"] stringByAppendingPathComponent:@"targets"];
}
- (NSString *)pathForTarget:(Target *)theTarget {
    return [[self targetsDir] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.target", [theTarget targetUUID]]];
}
- (void)targetFilesChanged {
    NSError *myError = nil;
    NSArray *theSortedTargets = [self sortedTargets:&myError];
    if (theSortedTargets == nil) {
        HSLogError(@"error reloading targets from files: %@", myError);
        return;
    }
    
    NSMutableDictionary *existingTargetsByUUID = [NSMutableDictionary dictionary];
    for (Target *existing in sortedTargets) {
        [existingTargetsByUUID setObject:existing forKey:[existing targetUUID]];
    }
    NSMutableDictionary *updatedTargetsByUUID = [NSMutableDictionary dictionary];
    for (Target *updated in theSortedTargets) {
        [updatedTargetsByUUID setObject:updated forKey:[updated targetUUID]];
    }
    
    [sortedTargets setArray:theSortedTargets];
    
    for (NSString *targetUUID in [existingTargetsByUUID allKeys]) {
        Target *existing = [existingTargetsByUUID objectForKey:targetUUID];
        Target *updated = [updatedTargetsByUUID objectForKey:targetUUID];
        if (updated == nil) {
            for (id <TargetFactoryChangeListener> listener in changeListeners) {
                [listener targetFactoryTargetWasDeleted:existing];
            }
        } else if (![existing isEqual:updated]) {
            for (id <TargetFactoryChangeListener> listener in changeListeners) {
                [listener targetFactoryTargetWasUpdatedFrom:existing to:updated];
            }
        }
        [updatedTargetsByUUID removeObjectForKey:targetUUID];
    }
    for (Target *added in [updatedTargetsByUUID allValues]) {
        for (id <TargetFactoryChangeListener> listener in changeListeners) {
            [listener targetFactoryTargetWasAdded:added];
        }
    }
}
@end
