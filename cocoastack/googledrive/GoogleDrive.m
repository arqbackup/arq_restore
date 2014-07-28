/*
 Copyright (c) 2009-2014, Stefan Reitshamer http://www.haystacksoftware.com
 
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


#import "GoogleDrive.h"
#import "GoogleDriveRequest.h"
#import "NSString+SBJSON.h"
#import "GoogleDriveFolderLister.h"
#import "NSObject+SBJSON.h"
#import "NSString_extra.h"
#import "S3ObjectMetadata.h"
#import "ISO8601Date.h"


static NSString *kFolderMimeType = @"application/vnd.google-apps.folder";


@implementation GoogleDrive
+ (NSString *)errorDomain {
    return @"GoogleDriveErrorDomain";
}
+ (NSURL *)endpoint {
    return [NSURL URLWithString:@"https://www.googleapis.com/drive"];
}

- (id)init {
    NSAssert(0==1, @"don't call this init method!");
    return nil;
}

- (id)initWithEmailAddress:(NSString *)theEmailAddress refreshToken:(NSString *)theRefreshToken delegate:(id<GoogleDriveDelegate>)theDelegate {
    if (self = [super init]) {
        emailAddress = [theEmailAddress retain];
        refreshToken = [theRefreshToken retain];
        delegate = theDelegate;
        NSAssert(delegate != nil, @"delegate may not be nil");
    }
    return self;
}
- (void)dealloc {
    [emailAddress release];
    [refreshToken release];
    [super dealloc];
}

- (NSDictionary *)aboutWithTargetConnectionDelegate:(id<TargetConnectionDelegate>)theTCD error:(NSError **)error {
    GoogleDriveRequest *req = [[[GoogleDriveRequest alloc] initWithEmailAddress:emailAddress method:@"GET" path:@"/drive/v2/about" queryString:nil refreshToken:refreshToken googleDriveDelegate:delegate dataTransferDelegate:nil error:error] autorelease];
    if (req == nil) {
        return nil;
    }
    
    NSData *response = [req dataWithTargetConnectionDelegate:theTCD error:error];
    if (response == nil) {
        return nil;
    }
    
    NSString *responseString = [[[NSString alloc] initWithData:response encoding:NSUTF8StringEncoding] autorelease];
    return (NSDictionary *)[responseString JSONValue:error];
}
- (NSNumber *)fileExistsAtPath:(NSString *)thePath isDirectory:(BOOL *)isDirectory targetConnectionDelegate:(id<TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    return [self fileExistsAtPath:thePath isDirectory:isDirectory dataSize:NULL lastModifiedDate:NULL targetConnectionDelegate:theDelegate error:error];
}
- (NSNumber *)fileExistsAtPath:(NSString *)thePath dataSize:(unsigned long long *)theDataSize targetConnectionDelegate:(id<TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    return [self fileExistsAtPath:thePath isDirectory:NULL dataSize:theDataSize lastModifiedDate:NULL targetConnectionDelegate:theDelegate error:error];
}
- (NSNumber *)fileExistsAtPath:(NSString *)thePath isDirectory:(BOOL *)isDirectory dataSize:(unsigned long long *)theDataSize lastModifiedDate:(NSDate **)theLastModifiedDate targetConnectionDelegate:(id<TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    HSLogDetail(@"checking existence of %@", thePath);
    
    if ([thePath isEqualToString:@"/"]) {
        if (isDirectory != NULL) {
            *isDirectory = YES;
        }
        HSLogDebug(@"%@ exists", thePath);
        return YES;
    }
    NSError *myError = nil;
    NSDictionary *googleDriveItem = [self firstGoogleDriveItemAtPath:thePath targetConnectionDelegate:theDelegate error:&myError];
    if (googleDriveItem == nil) {
        if (![myError isErrorWithDomain:[GoogleDrive errorDomain] code:ERROR_NOT_FOUND]) {
            SETERRORFROMMYERROR;
            return nil;
        }
        HSLogDebug(@"%@ does not exist", thePath);
        return [NSNumber numberWithBool:NO];
    }
    
    if (isDirectory != NULL) {
        *isDirectory = [[googleDriveItem objectForKey:@"mimeType"] isEqualToString:kFolderMimeType];
    }
    if (theDataSize != NULL) {
        NSString *fileSize = [googleDriveItem objectForKey:@"fileSize"];
        *theDataSize = (unsigned long long)[fileSize integerValue];
    }
    if (theLastModifiedDate != NULL) {
        NSDate *date = [ISO8601Date dateFromString:[googleDriveItem objectForKey:@"modifiedDate"] error:error];
        if (date == nil) {
            return nil;
        }
        *theLastModifiedDate = date;
    }

    HSLogDebug(@"%@ exists", thePath);
    return [NSNumber numberWithBool:YES];
}
- (NSArray *)contentsOfDirectoryAtPath:(NSString *)thePath targetConnectionDelegate:(id<TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    HSLogDetail(@"getting contents of directory %@", thePath);
    
    if ([thePath hasSuffix:@"/"]) {
        thePath = [thePath substringToIndex:[thePath length] - 1];
    }
    NSError *myError = nil;
    NSString *folderId = [self folderIdForPath:thePath targetConnectionDelegate:theDelegate error:&myError];
    if (folderId == nil) {
        if (![myError isErrorWithDomain:[GoogleDrive errorDomain] code:ERROR_NOT_FOUND]) {
            SETERRORFROMMYERROR;
            return nil;
        }
        return [NSArray array];
    }
    
    GoogleDriveFolderLister *lister = [[[GoogleDriveFolderLister alloc] initWithEmailAddress:emailAddress refreshToken:refreshToken folderId:folderId googleDriveDelegate:delegate targetConnectionDelegate:theDelegate] autorelease];
    NSArray *googleDriveItems = [lister googleDriveItems:error];
    if (googleDriveItems == nil) {
        return nil;
    }
    
    NSMutableArray *ret = [NSMutableArray array];
    for (NSDictionary *item in googleDriveItems) {
        [ret addObject:[item objectForKey:@"title"]];
    }
    
    HSLogDebug(@"returning %ld items for directory %@", [ret count], thePath);
    return ret;
}
- (BOOL)createDirectoryAtPath:(NSString *)thePath withIntermediateDirectories:(BOOL)createIntermediates targetConnectionDelegate:(id<TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    HSLogDetail(@"creating directory %@", thePath);
    
    NSString *parentPath = [thePath stringByDeletingLastPathComponent];
    if (createIntermediates && ![thePath isEqualToString:@"/"]) {
        BOOL isDirectory = NO;
        NSNumber *exists = [self fileExistsAtPath:parentPath isDirectory:&isDirectory targetConnectionDelegate:nil error:error];
        if (exists == nil) {
            return NO;
        }
        if ([exists boolValue]) {
            if (!isDirectory) {
                SETNSERROR([GoogleDrive errorDomain], -1, @"%@ exists and is not a directory", parentPath);
                return NO;
            }
        } else {
            if (![self createDirectoryAtPath:parentPath withIntermediateDirectories:YES targetConnectionDelegate:theDelegate error:error]) {
                return NO;
            }
        }
    }
    
    NSString *parentFolderId = [self folderIdForPath:parentPath targetConnectionDelegate:theDelegate error:error];
    if (parentFolderId == nil) {
        return NO;
    }
    
    NSString *lastPathComponent = [thePath lastPathComponent];
    NSDictionary *parent = [NSDictionary dictionaryWithObject:parentFolderId forKey:@"id"];
    NSArray *parents = [NSArray arrayWithObject:parent];
    NSDictionary *requestJSON = [NSDictionary dictionaryWithObjectsAndKeys:
                                 lastPathComponent, @"title",
                                 parents, @"parents",
                                 kFolderMimeType, @"mimeType",
                                 nil];
    NSData *requestBody = [[requestJSON JSONRepresentation:error] dataUsingEncoding:NSUTF8StringEncoding];
    if (requestBody == nil) {
        return NO;
    }
    
    GoogleDriveRequest *req = [[[GoogleDriveRequest alloc] initWithEmailAddress:emailAddress
                                                                         method:@"POST"
                                                                           path:@"/drive/v2/files"
                                                                    queryString:nil
                                                                   refreshToken:refreshToken
                                                            googleDriveDelegate:delegate
                                                           dataTransferDelegate:nil
                                                                          error:error] autorelease];
    if (req == nil) {
        return NO;
    }
    [req setRequestHeader:@"application/json" forKey:@"Content-Type"];
    [req setRequestBody:requestBody];
    NSData *response = [req dataWithTargetConnectionDelegate:theDelegate error:error];
    if (response == nil) {
        return NO;
    }
    NSString *responseString = [[[NSString alloc] initWithData:response encoding:NSUTF8StringEncoding] autorelease];
    NSDictionary *responseJSON = [responseString JSONValue:error];
    if (responseJSON == nil) {
        return NO;
    }
    NSString *folderId = [responseJSON objectForKey:@"id"];
    [delegate googleDriveDidFindFolderId:folderId forPath:thePath refreshToken:refreshToken];
    
    return YES;
}
- (BOOL)removeItemAtPath:(NSString *)thePath targetConnectionDelegate:(id<TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    HSLogDetail(@"deleting %@", thePath);
    
    if ([thePath isEqualToString:@"/"]) {
        SETNSERROR([GoogleDrive errorDomain], -1, @"cannot delete root folder");
        return NO;
    }
    
    NSError *myError = nil;
    NSDictionary *googleDriveItem = [self firstGoogleDriveItemAtPath:thePath targetConnectionDelegate:theDelegate error:&myError];
    if (googleDriveItem == nil) {
        if (![myError isErrorWithDomain:[GoogleDrive errorDomain] code:ERROR_NOT_FOUND]) {
            SETERRORFROMMYERROR;
            return NO;
        }
    } else {
        NSString *fileId = [googleDriveItem objectForKey:@"id"];
        GoogleDriveRequest *req = [[[GoogleDriveRequest alloc] initWithEmailAddress:emailAddress
                                                                             method:@"DELETE"
                                                                               path:[NSString stringWithFormat:@"/drive/v2/files/%@", fileId]
                                                                        queryString:nil
                                                                       refreshToken:refreshToken
                                                                googleDriveDelegate:delegate
                                                               dataTransferDelegate:nil
                                                                              error:error] autorelease];
        if (req == nil) {
            return NO;
        }
        if ([req dataWithTargetConnectionDelegate:theDelegate error:&myError] == nil) {
            // If we do a DELETE and the network goes away, the delete may have happened, so when the network comes back and we retry
            // we might get file-not-found. Don't return an error in that case.
            if (![myError isErrorWithDomain:[GoogleDrive errorDomain] code:ERROR_NOT_FOUND]) {
                SETERRORFROMMYERROR;
                return NO;
            }
        }
    }
    return YES;
}
- (NSData *)contentsOfFileAtPath:(NSString *)thePath dataTransferDelegate:(id<DataTransferDelegate>)theDTDelegate targetConnectionDelegate:(id<TargetConnectionDelegate>)theTCDelegate error:(NSError **)error {
    HSLogDetail(@"getting contents of file %@", thePath);
    
    NSDictionary *googleDriveItem = [self firstGoogleDriveItemAtPath:thePath targetConnectionDelegate:theTCDelegate error:error];
    if (googleDriveItem == nil) {
        return nil;
    }
    
    NSURL *downloadURL = [NSURL URLWithString:[googleDriveItem objectForKey:@"downloadUrl"]];
    
    GoogleDriveRequest *req = [[[GoogleDriveRequest alloc] initWithGetURL:downloadURL refreshToken:refreshToken googleDriveDelegate:delegate dataTransferDelegate:theDTDelegate error:error] autorelease];
    NSData *response = [req dataWithTargetConnectionDelegate:theTCDelegate error:error];
    return response;
}
- (BOOL)writeData:(NSData *)theData mimeType:(NSString *)theMimeType toFileAtPath:(NSString *)thePath dataTransferDelegate:(id <DataTransferDelegate>)theDelegate targetConnectionDelegate:(id <TargetConnectionDelegate>)theTCD error:(NSError **)error {
    HSLogDebug(@"putting file %@", thePath);
    
    // FIXME! Hack: If it's in /objects, we checked the object list so don't check for existence of the file:
    NSArray *pathComponents = [thePath pathComponents];
    if ([pathComponents count] > 2 && [[pathComponents objectAtIndex:[pathComponents count] - 1] length] == 40 && [[pathComponents objectAtIndex:[pathComponents count] - 2] isEqualToString:@"objects"]) {
        HSLogDebug(@"skipping existence check for %@", thePath);
    } else {
        // Delete existing file if any.
        if (![self removeItemAtPath:thePath targetConnectionDelegate:theTCD error:error]) {
            return NO;
        }
    }
    
    
    NSString *parentPath = [thePath stringByDeletingLastPathComponent];
    
    NSError *myError = nil;
    NSString *folderId = [self folderIdForPath:parentPath targetConnectionDelegate:theTCD error:&myError];
    if (folderId == nil) {
        if (![myError isErrorWithDomain:[GoogleDrive errorDomain] code:ERROR_NOT_FOUND]) {
            SETERRORFROMMYERROR;
            return NO;
        }
        if (![self createDirectoryAtPath:parentPath withIntermediateDirectories:YES targetConnectionDelegate:theTCD error:error]) {
            return NO;
        }
        folderId = [self folderIdForPath:parentPath targetConnectionDelegate:theTCD error:error];
        if (folderId == nil) {
            return NO;
        }
    }
    
    GoogleDriveRequest *req = [[[GoogleDriveRequest alloc] initWithEmailAddress:emailAddress
                                                                         method:@"POST"
                                                                     path:@"/upload/drive/v2/files"
                                                              queryString:@"uploadType=multipart"
                                                             refreshToken:refreshToken
                                                      googleDriveDelegate:delegate
                                                     dataTransferDelegate:theDelegate
                                                                    error:error] autorelease];
    if (req == nil) {
        return NO;
    }
    
    NSString *lastPathComponent = [thePath lastPathComponent];
    NSDictionary *parent = [NSDictionary dictionaryWithObject:folderId forKey:@"id"];
    NSArray *parents = [NSArray arrayWithObject:parent];
    NSDictionary *requestParams = [NSDictionary dictionaryWithObjectsAndKeys:
                                   lastPathComponent, @"title",
                                   theMimeType, @"mimeType",
                                   parents, @"parents", nil];
    NSString *requestJSON = [requestParams JSONRepresentation:error];
    if (requestJSON == nil) {
        return NO;
    }
    
    NSString *uuid = [NSString stringWithRandomUUID];
    [req setRequestHeader:[NSString stringWithFormat:@"multipart/related; boundary=\"%@\"", uuid] forKey:@"Content-Type"];
    NSMutableData *requestBody = [NSMutableData data];
    [requestBody appendData:[[NSString stringWithFormat:@"--%@\n", uuid] dataUsingEncoding:NSUTF8StringEncoding]];
    [requestBody appendData:[@"Content-Type: application/json; charset=UTF-8\n" dataUsingEncoding:NSUTF8StringEncoding]];
    [requestBody appendData:[@"\n" dataUsingEncoding:NSUTF8StringEncoding]];
    [requestBody appendData:[requestJSON dataUsingEncoding:NSUTF8StringEncoding]];
    [requestBody appendData:[@"\n" dataUsingEncoding:NSUTF8StringEncoding]];
    
    [requestBody appendData:[[NSString stringWithFormat:@"--%@\n", uuid] dataUsingEncoding:NSUTF8StringEncoding]];
    [requestBody appendData:[[NSString stringWithFormat:@"Content-Type: %@\n", theMimeType] dataUsingEncoding:NSUTF8StringEncoding]];
    [requestBody appendData:[@"\n" dataUsingEncoding:NSUTF8StringEncoding]];
    [requestBody appendData:theData];
    [requestBody appendData:[@"\n" dataUsingEncoding:NSUTF8StringEncoding]];
    [requestBody appendData:[[NSString stringWithFormat:@"--%@--\n", uuid] dataUsingEncoding:NSUTF8StringEncoding]];
    
    [req setRequestBody:requestBody];
    
    NSData *response = [req dataWithTargetConnectionDelegate:theTCD error:error];
    return response != nil;
}
- (NSNumber *)sizeOfItemAtPath:(NSString *)thePath targetConnectionDelegate:(id<TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    HSLogDetail(@"getting size of %@", thePath);
    
    NSError *myError = nil;
    NSDictionary *googleDriveItem = [self firstGoogleDriveItemAtPath:thePath targetConnectionDelegate:theDelegate error:&myError];
    if (googleDriveItem == nil) {
        if (![myError isErrorWithDomain:[GoogleDrive errorDomain] code:ERROR_NOT_FOUND]) {
            SETERRORFROMMYERROR;
            return nil;
        }
        HSLogDebug(@"path %@ does not exist; returning size = 0", thePath);
        return [NSNumber numberWithUnsignedInteger:0];
    }
    
    return [self sizeOfGoogleDriveItem:googleDriveItem targetConnectionDelegate:theDelegate error:error];
}
- (NSArray *)objectsAtPath:(NSString *)thePath targetConnectionDelegate:(id<TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    HSLogDetail(@"getting objects at %@", thePath);
    
    thePath = [thePath stringByDeletingTrailingSlash];
    BOOL isDir = NO;
    unsigned long long dataSize = NULL;
    NSDate *lastModifiedDate = nil;
    NSError *myError = nil;
    NSNumber *exists = [self fileExistsAtPath:thePath isDirectory:&isDir dataSize:&dataSize lastModifiedDate:&lastModifiedDate targetConnectionDelegate:theDelegate error:&myError];
    if (exists == nil) {
        SETERRORFROMMYERROR;
        return nil;
    }
    
    NSArray *ret = nil;
    if (![exists boolValue]) {
        ret = [NSArray array];
    } else if (isDir) {
        ret = [self objectsInDirectory:thePath targetConnectionDelegate:theDelegate error:error];
    } else {
        S3ObjectMetadata *md = [[[S3ObjectMetadata alloc] initWithPath:thePath lastModified:lastModifiedDate size:dataSize storageClass:@"STANDARD"] autorelease];
        ret = [NSArray arrayWithObject:md];
    }
    return ret;
}
- (NSArray *)pathsOfObjectsAtPath:(NSString *)thePath targetConnectionDelegate:(id<TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    HSLogDetail(@"getting paths of objects at %@", thePath);
    
    BOOL isDirectory = NO;
    NSNumber *exists = [self fileExistsAtPath:thePath isDirectory:&isDirectory targetConnectionDelegate:theDelegate error:error];
    if (exists == nil) {
        return nil;
    }
    NSArray *ret = nil;
    if (![exists boolValue]) {
        ret = [NSArray array];
    } else if (isDirectory) {
        ret = [self pathsOfObjectsInDirectory:thePath targetConnectionDelegate:theDelegate error:error];
    } else {
        ret = [NSArray arrayWithObject:thePath];
    }
    return ret;
}


#pragma mark internal
- (NSArray *)objectsInDirectory:(NSString *)thePath targetConnectionDelegate:(id<TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    NSString *folderId = [self folderIdForPath:thePath targetConnectionDelegate:theDelegate error:error];
    if (folderId == nil) {
        return nil;
    }

    GoogleDriveFolderLister *lister = [[[GoogleDriveFolderLister alloc] initWithEmailAddress:emailAddress refreshToken:refreshToken folderId:folderId googleDriveDelegate:delegate targetConnectionDelegate:theDelegate] autorelease];
    NSArray *googleDriveItems = [lister googleDriveItems:error];
    if (googleDriveItems == nil) {
        return nil;
    }
    
    NSMutableArray *ret = [NSMutableArray array];
    for (NSDictionary *googleDriveItem in googleDriveItems) {
        NSString *name = [googleDriveItem objectForKey:@"title"];
        NSString *childPath = [thePath stringByAppendingPathComponent:name];
        if ([[googleDriveItem objectForKey:@"mimeType"] isEqualToString:kFolderMimeType]) {
            NSArray *childObjects = [self objectsInDirectory:childPath targetConnectionDelegate:theDelegate error:error];
            if (childObjects == nil) {
                return nil;
            }
            [ret addObjectsFromArray:childObjects];
        } else {
            NSDate *lastModifiedDate = [ISO8601Date dateFromString:[googleDriveItem objectForKey:@"modifiedDate"] error:error];
            if (lastModifiedDate == nil) {
                return nil;
            }
            NSNumber *dataSize = [googleDriveItem objectForKey:@"fileSize"];
            S3ObjectMetadata *md = [[[S3ObjectMetadata alloc] initWithPath:childPath lastModified:lastModifiedDate size:dataSize storageClass:@"STANDARD"] autorelease];
            [ret addObject:md];
        }
    }
    return ret;
}
- (NSArray *)pathsOfObjectsInDirectory:(NSString *)thePath targetConnectionDelegate:(id<TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    NSString *folderId = [self folderIdForPath:thePath targetConnectionDelegate:theDelegate error:error];
    if (folderId == nil) {
        return nil;
    }
    
    GoogleDriveFolderLister *lister = [[[GoogleDriveFolderLister alloc] initWithEmailAddress:emailAddress
                                                                                refreshToken:refreshToken
                                                                                    folderId:folderId
                                                                         googleDriveDelegate:delegate
                                                                    targetConnectionDelegate:theDelegate] autorelease];
    NSArray *googleDriveItems = [lister googleDriveItems:error];
    if (googleDriveItems == nil) {
        return nil;
    }
    
    NSMutableArray *ret = [NSMutableArray array];
    for (NSDictionary *googleDriveItem in googleDriveItems) {
        NSString *name = [googleDriveItem objectForKey:@"title"];
        NSString *childPath = [thePath stringByAppendingPathComponent:name];
        if ([[googleDriveItem objectForKey:@"mimeType"] isEqualToString:kFolderMimeType]) {
            NSArray *childPaths = [self pathsOfObjectsInDirectory:childPath targetConnectionDelegate:theDelegate error:error];
            if (childPaths == nil) {
                return nil;
            }
            [ret addObjectsFromArray:childPaths];
        } else {
            [ret addObject:childPath];
        }
    }
    return ret;
}
- (NSString *)folderIdForPath:(NSString *)thePath targetConnectionDelegate:(id<TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    NSString *folderId = [delegate googleDriveFolderIdForPath:thePath refreshToken:refreshToken];
    if (folderId != nil) {
        return folderId;
    }
    
    NSString *lastPathComponent = [thePath lastPathComponent];
    NSString *parentPath = [thePath stringByDeletingLastPathComponent];
    NSString *parentFolderId = [self folderIdForPath:parentPath targetConnectionDelegate:theDelegate error:error];
    if (parentFolderId == nil) {
        return nil;
    }
    
    GoogleDriveFolderLister *lister = [[[GoogleDriveFolderLister alloc] initWithEmailAddress:emailAddress
                                                                                refreshToken:refreshToken
                                                                                    folderId:parentFolderId
                                                                                        name:lastPathComponent
                                                                         googleDriveDelegate:delegate
                                                                    targetConnectionDelegate:theDelegate] autorelease];
    NSArray *googleDriveItems = [lister googleDriveItems:error];
    if (googleDriveItems == nil) {
        return nil;
    }

    for (NSDictionary *item in googleDriveItems) {
        if ([[item objectForKey:@"title"] isEqualToString:lastPathComponent]) {
            if (![[item objectForKey:@"mimeType"] isEqualToString:kFolderMimeType]) {
                SETNSERROR([GoogleDrive errorDomain], -1, @"%@ is not a folder", thePath);
            }
            [delegate googleDriveDidFindFolderId:[item objectForKey:@"id"] forPath:thePath refreshToken:refreshToken];
            return [item objectForKey:@"id"];
        }
    }
    SETNSERROR([GoogleDrive errorDomain], ERROR_NOT_FOUND, @"folderId not found for path %@", thePath);
    return nil;
}
/*
 * NOTE: This method ONLY RETURNS THE FIRST ITEM found with the given name.
 * Google Drive API allows more than one item with the same name in the same folder, unfortunately.
 */
- (NSDictionary *)firstGoogleDriveItemAtPath:(NSString *)thePath targetConnectionDelegate:(id<TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    NSString *parentPath = [thePath stringByDeletingLastPathComponent];
    NSString *folderId = [self folderIdForPath:parentPath targetConnectionDelegate:theDelegate error:error];
    if (folderId == nil) {
        return nil;
    }
    NSString *lastPathComponent = [thePath lastPathComponent];
    GoogleDriveFolderLister *lister = [[[GoogleDriveFolderLister alloc] initWithEmailAddress:emailAddress
                                                                                refreshToken:refreshToken
                                                                                    folderId:folderId name:lastPathComponent
                                                                         googleDriveDelegate:delegate
                                                                    targetConnectionDelegate:theDelegate] autorelease];
    NSArray *googleDriveItems = [lister googleDriveItems:error];
    if (googleDriveItems == nil) {
        return nil;
    }
    
    NSDictionary *ret = nil;
    for (NSDictionary *item in googleDriveItems) {
        if ([[item objectForKey:@"title"] isEqualToString:lastPathComponent]) {
            if ([[item objectForKey:@"mimeType"] isEqualToString:kFolderMimeType]) {
                [delegate googleDriveDidFindFolderId:[item objectForKey:@"id"] forPath:thePath refreshToken:refreshToken];
            }
            ret = item;
            break;
        }
    }
    if (ret == nil) {
        SETNSERROR([GoogleDrive errorDomain], ERROR_NOT_FOUND, @"%@ not found in %@", lastPathComponent, parentPath);
    }
    return ret;
}
- (NSNumber *)sizeOfGoogleDriveItem:(NSDictionary *)theGoogleDriveItem targetConnectionDelegate:(id<TargetConnectionDelegate>)theDelegate error:(NSError **)error {
    if (![[theGoogleDriveItem objectForKey:@"mimeType"] isEqualToString:kFolderMimeType]) {
        NSString *theFileSize = [theGoogleDriveItem objectForKey:@"fileSize"];
        return [NSNumber numberWithInteger:[theFileSize integerValue]];
    }
    
    GoogleDriveFolderLister *lister = [[[GoogleDriveFolderLister alloc] initWithEmailAddress:emailAddress
                                                                                refreshToken:refreshToken
                                                                                    folderId:[theGoogleDriveItem objectForKey:@"id"]
                                                                         googleDriveDelegate:delegate
                                                                    targetConnectionDelegate:theDelegate] autorelease];
    NSArray *googleDriveItems = [lister googleDriveItems:error];
    if (googleDriveItems == nil) {
        return nil;
    }
    
    unsigned long long total = 0;
    for (NSDictionary *childGoogleDriveItem in googleDriveItems) {
        NSNumber *childSize = [self sizeOfGoogleDriveItem:childGoogleDriveItem targetConnectionDelegate:theDelegate error:error];
        if (childSize == nil) {
            return nil;
        }
        total += [childSize unsignedLongLongValue];
    }
    return [NSNumber numberWithUnsignedLongLong:total];
}
@end
