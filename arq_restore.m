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



#include <libgen.h>
#import <Foundation/Foundation.h>
#import "ArqRestoreCommand.h"


static void printUsage(const char *exeName) {
	fprintf(stderr, "Usage:\n");
    fprintf(stderr, "\t%s [-l loglevel] listtargets\n", exeName);
    fprintf(stderr, "\t%s [-l loglevel] addtarget <nickname> aws <access_key>\n", exeName);
    fprintf(stderr, "\t%s [-l loglevel] addtarget <nickname> local <path>\n", exeName);
    fprintf(stderr, "\t%s [-l loglevel] deletetarget <nickname>\n", exeName);
    fprintf(stderr, "\n");
    fprintf(stderr, "\t%s [-l loglevel] listcomputers <target_nickname>\n", exeName);
    fprintf(stderr, "\t%s [-l loglevel] listfolders <target_nickname> <computer_uuid>\n", exeName);
    fprintf(stderr, "\t%s [-l loglevel] printplist <target_nickname> <computer_uuid> <folder_uuid>\n", exeName);
    fprintf(stderr, "\t%s [-l loglevel] listtree <target_nickname> <computer_uuid> <folder_uuid>\n", exeName);
    fprintf(stderr, "\t%s [-l loglevel] restore <target_nickname> <computer_uuid> <folder_uuid> [relative_path]\n", exeName);
    fprintf(stderr, "\t%s [-l loglevel] clearcache <target_nickname>\n", exeName);
    fprintf(stderr, "\n");
    fprintf(stderr, "log levels: none, error, warn, info, and debug\n");
    fprintf(stderr, "log output: ~/Library/Logs/arq_restorer\n");
}
int main (int argc, const char **argv) {
    char *exePath = strdup(argv[0]);
    char *exeName = basename(exePath);
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    ArqRestoreCommand *cmd = [[[ArqRestoreCommand alloc] init] autorelease];
    int ret = 0;
    if (argc == 2 && !strcmp(argv[1], "-h")) {
        printUsage(exeName);
    } else {
        NSError *myError = nil;
        if (![cmd executeWithArgc:argc argv:argv error:&myError]) {
            fprintf(stderr, "%s: %s\n", exeName, [[myError localizedDescription] UTF8String]);

            if ([myError isErrorWithDomain:[cmd errorDomain] code:ERROR_USAGE]) {
                printUsage(exeName);
            }
            ret = 1;
        }
    }
    [pool drain];
    free(exePath);
    return ret;
}
