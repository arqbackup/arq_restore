//
//  LifecycleConfiguration.h
//  Arq
//
//  Created by Stefan Reitshamer on 2/21/14.
//  Copyright (c) 2014 Stefan Reitshamer. All rights reserved.
//


@interface LifecycleConfiguration : NSObject <NSXMLParserDelegate> {
    NSMutableArray *elementNames;
    NSMutableString *currentStringBuffer;
    NSMutableArray *ruleIds;
    BOOL errorOccurred;
    NSError *myError;
}
- (id)initWithData:(NSData *)theData error:(NSError **)error;
- (BOOL)containsRuleWithId:(NSString *)theId;
@end
