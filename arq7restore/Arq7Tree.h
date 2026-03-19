/*
 Arq7Tree — port of arq7's Tree.h for use in arq_restore.
 Uses Arq7* prefix to avoid conflicts with arq_restore's existing Arq5 Tree class.
*/

@class Arq7Node;
@class BufferedInputStream;

@interface Arq7Tree : NSObject

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithBufferedInputStream:(BufferedInputStream *)bis error:(NSError **)error;
- (instancetype)initWithJSON:(NSDictionary *)theJSON error:(NSError **)error;

- (uint32_t)version;
- (NSArray *)childNodeNames;
- (Arq7Node *)childNodeWithName:(NSString *)theName;
@end
