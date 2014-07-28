//
//  RemoteFS.h
//  Arq
//
//  Created by Stefan Reitshamer on 3/18/14.
//  Copyright (c) 2014 Stefan Reitshamer. All rights reserved.
//

@protocol DataTransferDelegate;
@protocol TargetConnectionDelegate;


@protocol RemoteFS <NSObject>
- (NSString *)errorDomain;

- (NSNumber *)fileExistsAtPath:(NSString *)thePath isDirectory:(BOOL *)isDirectory targetConnectionDelegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error;
- (NSNumber *)fileExistsAtPath:(NSString *)thePath dataSize:(unsigned long long *)theDataSize targetConnectionDelegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error;
- (NSArray *)contentsOfDirectoryAtPath:(NSString *)thePath targetConnectionDelegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error;
- (NSData *)contentsOfFileAtPath:(NSString *)thePath dataTransferDelegate:(id <DataTransferDelegate>)theDTDelegate targetConnectionDelegate:(id <TargetConnectionDelegate>)theTCDelegate error:(NSError **)error;
- (BOOL)writeData:(NSData *)theData atomicallyToFileAtPath:(NSString *)thePath dataTransferDelegate:(id <DataTransferDelegate>)theDTDelegate targetConnectionDelegate:(id <TargetConnectionDelegate>)theTCDelegate error:(NSError **)error;
- (BOOL)removeItemAtPath:(NSString *)thePath targetConnectionDelegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error;
- (BOOL)createDirectoryAtPath:(NSString *)path withIntermediateDirectories:(BOOL)createIntermediates targetConnectionDelegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error;
- (NSNumber *)sizeOfItemAtPath:(NSString *)thePath targetConnectionDelegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error;
- (NSArray *)objectsAtPath:(NSString *)thePath targetConnectionDelegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error;
- (NSArray *)pathsOfObjectsAtPath:(NSString *)thePath targetConnectionDelegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error;
- (NSNumber *)isObjectRestoredAtPath:(NSString *)thePath targetConnectionDelegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error;
- (BOOL)restoreObjectAtPath:(NSString *)thePath forDays:(NSUInteger)theDays alreadyRestoredOrRestoring:(BOOL *)alreadyRestoredOrRestoring targetConnectionDelegate:(id <TargetConnectionDelegate>)theDelegate error:(NSError **)error;
@end
