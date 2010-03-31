/*
 Copyright (c) 2009, Stefan Reitshamer http://www.haystacksoftware.com
 
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

#include <libgen.h>
#import <Foundation/Foundation.h>
#import "ArqRestoreCommand.h"
#import "ArqFolder.h"

static void printUsage(const char *exeName) {
    fprintf(stderr, "\t%s\n", exeName);
    fprintf(stderr, "\t%s /s3bucket/computerUUID/folderUUID\n", exeName);
}
int main (int argc, const char * argv[]) {
    setHSLogLevel(HSLOG_LEVEL_ERROR);
    char *exePath = strdup(argv[0]);
    char *exeName = basename(exePath);
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    ArqRestoreCommand *cmd = [[[ArqRestoreCommand alloc] init] autorelease];
    int ret = 0;
    NSError *error = nil;
    if (argc == 1) {
        if (![cmd printArqFolders:&error]) {
            NSLog(@"%@", [error localizedDescription]);
            ret = 1;
        } else {
            printf("\nType %s <s3 path> to restore\n", exeName);
        }
    } else if (argc == 2) {
        if (![cmd restorePath:[NSString stringWithUTF8String:argv[1]] error:&error]) {
            NSLog(@"%@", [error localizedDescription]);
            ret = 1;
        }
    } else {
        printUsage(exeName);
        ret = 1;
    }
    [pool drain];
    free(exePath);
    return ret;
}
