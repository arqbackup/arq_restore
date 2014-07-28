//
//  Target.h
//  arq_restore
//
//  Created by Stefan Reitshamer on 7/28/14.
//
//

@protocol TargetConnection;
@class S3Service;
@class BufferedInputStream;


enum TargetType {
    kTargetAWS = 0,
    kTargetSFTP = 1,
    kTargetGreenQloud = 2,
    kTargetDreamObjects = 3,
    kTargetGoogleCloudStorage = 4,
    kTargetS3Compatible = 5,
    kTargetGoogleDrive = 6
};
typedef int TargetType;


@interface Target : NSObject {
    NSString *uuid;
    NSURL *endpoint;
    TargetType targetType;
    NSString *secret;
    NSString *passphrase;

    BOOL budgetEnabled;
    double budgetDollars;
    uint32_t budgetGB;
    BOOL useRRS;
}

- (id)initWithEndpoint:(NSURL *)theEndpoint secret:(NSString *)theSecret passphrase:(NSString *)thePassphrase;
- (id)initWithBufferedInputStream:(BufferedInputStream *)theBIS error:(NSError **)error;

- (NSString *)targetUUID;
- (NSURL *)endpoint;
- (NSString *)endpointDisplayName;
- (NSString *)secret:(NSError **)error;
- (NSString *)passphrase:(NSError **)error;
- (TargetType)targetType;
- (id <TargetConnection>)newConnection;
- (S3Service *)s3:(NSError **)error;
@end
