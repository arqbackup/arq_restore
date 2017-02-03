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



#import "FSStat.h"
#import "OSStatusDescription.h"
#import "Volume.h"
#import "NSString_slashed.h"


@interface FSStat ()
- (NSURL *)urlForMountPoint:(NSString *)theMountPoint error:(NSError **)error;
@end

@implementation FSStat
- (void)dealloc {
    if (buf != NULL) {
        free(buf);
    }
    [super dealloc];
}

- (NSString *)errorDomain {
    return @"FSStatErrorDomain";
}

- (NSArray *)mountedVolumes:(NSError **)error {
    if (![self loadFSStat:error]) {
        return nil;
    }
    NSMutableArray *array = [NSMutableArray array];
    for (int i = 0; i < count; i++) {
        struct statfs *fs = buf + i;
        NSString *theFSTypeName = [NSString stringWithUTF8String:fs->f_fstypename];
        NSString *theMountPoint = [NSString stringWithUTF8String:fs->f_mntonname];
        NSString *theFileSystem = [NSString stringWithUTF8String:fs->f_mntfromname];
        BOOL isRemote = (fs->f_flags & MNT_LOCAL) == 0;
        if ([theMountPoint length] == 0) {
            HSLogDebug(@"skipping empty mount point: %@", theMountPoint);
        } else {
            HSLogDebug(@"theFSTypeName=%@, theMountPoint=%@, theFileSystem=%@", theFSTypeName, theMountPoint, theFileSystem);
            FSRef volRef;
            // Skip if FSPathMakeRef fails.
            OSStatus oss = FSPathMakeRef((const UInt8 *)[theMountPoint fileSystemRepresentation], &volRef, NULL);
            if (oss != noErr) {
                HSLogDebug(@"skipping %@ because FSPathMakeRef failed: %@", theMountPoint, [OSStatusDescription descriptionForOSStatus:oss]);
            } else if ([theMountPoint length] == 0) {
                HSLogDebug(@"skipping empty mount point");
            } else {
                NSURL *theURL = nil;
                if ([theFSTypeName isEqualToString:@"hfs"] || [theFSTypeName isEqualToString:@"devfs"] || [theFSTypeName isEqualToString:@"autofs"]) {
                    NSString *escapedMountPoint = [theMountPoint stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
                    NSString *theURLString = [NSString stringWithFormat:@"file://localhost%@", escapedMountPoint];
                    theURL = [NSURL URLWithString:theURLString];
                } else {
                    theURL = [self urlForMountPoint:theMountPoint error:error];
                    if (theURL == nil) {
                        return nil;
                    }
                }
                if (![theFSTypeName isEqualToString:@"hfs"]) {
                    isRemote = YES;
                }
                if (theURL == nil) {
                    SETNSERROR([self errorDomain], -1, @"unable to create URL for %@", theMountPoint);
                    return nil;
                }
                NSAssert(theURL != nil, @"theURL can't be nil");
                if (![theFileSystem isEqualToString:@"devfs"] && ![theFileSystem hasPrefix:@"map "]) {
                    Volume *vol = [[Volume alloc] initWithURL:theURL mountPoint:theMountPoint fileSystem:theFileSystem fsTypeName:theFSTypeName fsType:fs->f_type owner:fs->f_owner name:[self volumeNameForPath:theMountPoint] isRemote:isRemote];
                    [array addObject:vol];
                    [vol release];
                }
            }
        }
    }
    return array;
    
}
- (NSString *)mountPointForPath:(NSString *)path error:(NSError **)error {
    return [[self volumeForPath:path error:error] mountPoint];
}
- (Volume *)volumeForPath:(NSString *)path error:(NSError **)error {
    NSArray *mountedVolumes = [self mountedVolumes:error];
    if (mountedVolumes == nil) {
        return nil;
    }
    NSMutableDictionary *mountedVolumesByMountPoint = [NSMutableDictionary dictionary];
    for (Volume *vol in mountedVolumes) {
        [mountedVolumesByMountPoint setObject:vol forKey:[vol mountPoint]];
    }
    NSMutableArray *mountPoints = [NSMutableArray arrayWithArray:[mountedVolumesByMountPoint allKeys]];
    NSSortDescriptor *descriptor = [[[NSSortDescriptor alloc] initWithKey:@"description" ascending:NO] autorelease];
    [mountPoints sortUsingDescriptors:[NSArray arrayWithObject:descriptor]];
    
    Volume *ret = nil;
    NSString *pathSlashed = [path slashed];
    for (NSUInteger index = 0; index < [mountPoints count]; index++) {
        NSString *theMountPoint = [mountPoints objectAtIndex:index];
        NSString *mountPointSlashed = [theMountPoint slashed];
        if ([pathSlashed hasPrefix:mountPointSlashed] && ![theMountPoint isEqualToString:@"/"]) {
            ret = [mountedVolumesByMountPoint objectForKey:theMountPoint];
            break;
        }
    }
    if (ret == nil) {
        ret = [mountedVolumesByMountPoint objectForKey:@"/"];
        if (ret == nil) {
            SETNSERROR([self errorDomain], ERROR_NOT_FOUND, @"volume not found for %@", path);
        }
    }
    return ret;
}
- (NSString *)volumeNameForPath:(NSString *)path {
    NSString *ret = @"";
    NSURL *pathURL = [NSURL fileURLWithPath:path];
    FSRef bundleRef;
    FSCatalogInfo info;
    HFSUniStr255 volName;
    if (CFURLGetFSRef((CFURLRef)pathURL, &bundleRef)) {
        if (FSGetCatalogInfo(&bundleRef, kFSCatInfoVolume, &info, NULL, NULL, NULL) == noErr) {
            if ( FSGetVolumeInfo ( info.volume, 0, NULL, kFSVolInfoNone, NULL, &volName, NULL) == noErr) {
                CFStringRef stringRef = FSCreateStringFromHFSUniStr(NULL, &volName);
                if (stringRef) {
                    char *volName = NewPtr(CFStringGetLength(stringRef)+1);
                    CFStringGetCString(stringRef, volName, CFStringGetLength(stringRef)+1, kCFStringEncodingMacRoman);
                    CFRelease(stringRef);
                    ret = [NSString stringWithUTF8String:volName];
                    DisposePtr(volName);
                }
            }
        }
    }
    return ret;
}


#pragma mark internal
- (NSURL *)urlForMountPoint:(NSString *)theMountPoint error:(NSError **)error {
    //            FSRef volRef;
    //            FSCatalogInfo volCatInfo;
    //            FSPathMakeRef((const UInt8 *)theStat->f_mntonname, &volRef, NULL);
    //            FSGetCatalogInfo(&volRef, kFSCatInfoVolume, &volCatInfo, NULL, NULL, NULL);
    //            FSVolumeRefNum vRefNum = volCatInfo.volume;
    //            CFURLRef url;
    //            FSCopyURLForVolume(vRefNum, &url);
    FSRef volRef;
    OSStatus oss = FSPathMakeRef((const UInt8 *)[theMountPoint fileSystemRepresentation], &volRef, NULL);
    if (oss != noErr) {
        SETNSERROR([self errorDomain], oss, @"FSPathMakeRef(%@): %@", theMountPoint, [OSStatusDescription descriptionForOSStatus:oss]);
        return nil;
    }
    FSCatalogInfo volCatInfo;
    OSErr oserr = FSGetCatalogInfo(&volRef, kFSCatInfoVolume, &volCatInfo, NULL, NULL, NULL);
    if (oserr) {
        SETNSERROR([self errorDomain], -1, @"FSGetCatalogInfo(%@): %@", theMountPoint, [OSStatusDescription descriptionForOSStatus:(OSStatus)oserr]);
        return nil;
    }
    CFURLRef theURL;
    oss = FSCopyURLForVolume(volCatInfo.volume, &theURL);
    if (oss != noErr) {
        SETNSERROR([self errorDomain], oss, @"FSCopyURLForVolume(%@): %@", theMountPoint, [OSStatusDescription descriptionForOSStatus:oss]);
        return nil;
    }
    return [(NSURL *)theURL autorelease];
}
- (BOOL)loadFSStat:(NSError **)error {
    if (buf != NULL) {
        free(buf);
        buf = NULL;
    }
    count = getfsstat(NULL, 0, MNT_WAIT);
    if (count == -1) {
        int errnum = errno;
        HSLogError(@"getfsstat error %d: %s", errnum, strerror(errnum));
        SETNSERROR(@"UnixErrorDomain", errnum, @"failed to get filesystem info: %s", strerror(errnum));
        return NO;
    }
    size_t bufsize = count * sizeof(struct statfs);
    buf = (struct statfs *)malloc(bufsize);
    int ret = getfsstat(buf, (int)bufsize, MNT_WAIT);
    if (ret == -1) {
        int errnum = errno;
        HSLogError(@"getfsstat error %d: %s", errnum, strerror(errnum));
        SETNSERROR(@"UnixErrorDomain", errnum, @"failed to get filesystem info: %s", strerror(errnum));
        return NO;
    }
    return YES;
}
@end
