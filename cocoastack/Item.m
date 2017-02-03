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




#import "Item.h"
#import "StringIO.h"
#import "IntegerIO.h"
#import "BooleanIO.h"
#import "DateIO.h"


@implementation Item
@synthesize itemId;
@synthesize parentId;
@synthesize name;
@synthesize isDirectory;
@synthesize fileSize;
@synthesize fileLastModified;
@synthesize storageClass;
@synthesize checksum;
@synthesize createdDate;


- (void)dealloc {
    [itemId release];
    [parentId release];
    [name release];
    [fileLastModified release];
    [createdDate release];
    [storageClass release];
    [checksum release];
    [super dealloc];
}


#pragma mark NSCopying
- (id)copyWithZone:(NSZone *)zone {
    Item *ret = [[Item alloc] init];
    ret.itemId = itemId;
    ret.parentId = parentId;
    ret.name = name;
    ret.isDirectory = isDirectory;
    ret.fileSize = fileSize;
    ret.fileLastModified = fileLastModified;
    ret.createdDate = createdDate;
    ret.storageClass = storageClass;
    ret.checksum = checksum;
    
    return ret;
}


#pragma mark NSObject
- (NSString *)description {
    return [NSString stringWithFormat:@"<Item: name=%@,id=%@,parent=%@,isDir=%@,fileSize=%qu>", name, itemId, parentId, (isDirectory ? @"YES":@"NO"), fileSize];
}
@end
