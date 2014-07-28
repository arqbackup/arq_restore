//
//  CommitFailedFile.h
//
//  Created by Stefan Reitshamer on 2/22/10.
//  Copyright 2010 Haystack Software. All rights reserved.
//


@class BufferedInputStream;

@interface CommitFailedFile : NSObject {
    NSString *path;
    NSString *errorMessage;
}
- (id)initWithPath:(NSString *)thePath errorMessage:(NSString *)theErrorMessage;
- (id)initWithInputStream:(BufferedInputStream *)is error:(NSError **)error;
- (NSString *)path;
- (NSString *)errorMessage;
- (void)writeTo:(NSMutableData *)data;
- (BOOL)isEqualToCommitFailedFile:(CommitFailedFile *)cff;
@end
