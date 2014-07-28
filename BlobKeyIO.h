//
//  BlobKeyIO.h
//
//  Created by Stefan Reitshamer on 9/14/12.
//
//

@class BufferedInputStream;
@class BufferedOutputStream;
@class BlobKey;


@interface BlobKeyIO : NSObject {
    
}
+ (void)write:(BlobKey *)theBlobKey to:(NSMutableData *)data;
+ (BOOL)write:(BlobKey *)theBlobKey to:(BufferedOutputStream *)os error:(NSError **)error;
+ (BOOL)read:(BlobKey **)theBlobKey from:(BufferedInputStream *)is treeVersion:(int)theTreeVersion compressed:(BOOL)isCompressed error:(NSError **)error;
@end
