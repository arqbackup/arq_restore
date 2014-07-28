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


#import "Vault.h"
#import "ISO8601Date.h"


@implementation Vault
- (id)initWithAWSRegion:(AWSRegion *)theAWSRegion json:(NSDictionary *)theDict {
    if (self = [super init]) {
        awsRegion = [theAWSRegion retain];
        NSString *theCreationDate = [theDict objectForKey:@"CreationDate"];
        if (theCreationDate != nil && ![theCreationDate isKindOfClass:[NSNull class]]) {
            NSError *myError = nil;
            creationDate = [[ISO8601Date dateFromString:theCreationDate error:&myError] retain];
            if (creationDate == nil) {
                HSLogError(@"%@", myError);
            }
        }
        
        NSString *theLastInventoryDate = [theDict objectForKey:@"LastInventoryDate"];
        if (theLastInventoryDate != nil && ![theLastInventoryDate isKindOfClass:[NSNull class]]) {
            NSError *myError = nil;
            lastInventoryDate = [[ISO8601Date dateFromString:theLastInventoryDate error:&myError] retain];
            if (lastInventoryDate == nil) {
                HSLogError(@"%@", myError);
            }
        }
        
        vaultARN = [[theDict objectForKey:@"VaultARN"] retain];
        vaultName = [[theDict objectForKey:@"VaultName"] retain];
        numberOfArchives = (uint64_t)[[theDict objectForKey:@"NumberOfArchives"] unsignedLongLongValue];
        size = (uint64_t)[[theDict objectForKey:@"SizeInBytes"] unsignedLongLongValue];
    }
    return self;
}
- (void)dealloc {
    [awsRegion release];
    [creationDate release];
    [lastInventoryDate release];
    [vaultARN release];
    [vaultName release];
    [super dealloc];
}

- (AWSRegion *)awsRegion {
    return awsRegion;
}
- (NSDate *)creationDate {
    return creationDate;
}
- (NSDate *)lastInventoryDate {
    return lastInventoryDate;
}
- (uint64_t)numberOfArchives {
    return numberOfArchives;
}
- (uint64_t)size {
    return size;
}
- (NSString *)vaultARN {
    return vaultARN;
}
- (NSString *)vaultName {
    return vaultName;
}
@end
