/*
 Arq7Tree — port of arq7's Tree.m.
 Changes: SETNSERROR_ARC → SETNSERROR, Node → Arq7Node.
*/

#import "Arq7Tree.h"
#import "Arq7Node.h"
#import "IntegerIO.h"
#import "StringIO.h"
#import "BufferedInputStream.h"


@interface Arq7Tree() {
    uint32_t _version;
    NSDictionary *_childNodesByName;
}
@end


@implementation Arq7Tree

- (instancetype)initWithBufferedInputStream:(BufferedInputStream *)bis error:(NSError **)error {
    if (self = [super init]) {
        if (![IntegerIO readUInt32:&_version from:bis error:error]) {
            return nil;
        }
        uint64_t count = 0;
        if (![IntegerIO readUInt64:&count from:bis error:error]) {
            return nil;
        }
        NSMutableDictionary *dict = [NSMutableDictionary dictionary];
        for (uint64_t i = 0; i < count; i++) {
            NSString *name = nil;
            if (![StringIO read:&name from:bis error:error]) {
                return nil;
            }
            Arq7Node *node = [[Arq7Node alloc] initWithBufferedInputStream:bis treeVersion:(int)_version error:error];
            if (node == nil) {
                return nil;
            }
            [dict setObject:node forKey:name];
        }
        _childNodesByName = [NSDictionary dictionaryWithDictionary:dict];
    }
    return self;
}

- (instancetype)initWithJSON:(NSDictionary *)theJSON error:(NSError **)error {
    if (self = [super init]) {
        _version = [[theJSON objectForKey:@"version"] unsignedIntValue];
        NSMutableDictionary *dict = [NSMutableDictionary dictionary];
        NSDictionary *childNodesJSON = [theJSON objectForKey:@"childNodesByName"];
        for (NSString *nodeName in [childNodesJSON allKeys]) {
            Arq7Node *node = [[Arq7Node alloc] initWithJSON:[childNodesJSON objectForKey:nodeName] error:error];
            if (node == nil) {
                return nil;
            }
            [dict setObject:node forKey:nodeName];
        }
        _childNodesByName = dict;
    }
    return self;
}

- (uint32_t)version {
    return _version;
}
- (NSArray *)childNodeNames {
    return [_childNodesByName allKeys];
}
- (Arq7Node *)childNodeWithName:(NSString *)theName {
    return [_childNodesByName objectForKey:theName];
}
@end
