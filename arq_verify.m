/*
 Copyright (c) 2010, Stefan Reitshamer http://www.haystacksoftware.com
 
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
#import "ArqVerifyCommand.h"

static void printUsage(const char *exeName) {
	fprintf(stderr, "usage: %s [s3_bucket_name [computer_uuid [folder_uuid]]]\n", exeName);
}
int main (int argc, const char * argv[]) {
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    setHSLogLevel(HSLOG_LEVEL_ERROR);
    char *exePath = strdup(argv[0]);
    char *exeName = basename(exePath);

	char *cAccessKey = getenv("ARQ_ACCESS_KEY");
	if (cAccessKey == NULL) {
		fprintf(stderr, "%s: missing ARQ_ACCESS_KEY environment variable\n", exeName);
	}
	char *cSecretKey = getenv("ARQ_SECRET_KEY");
	if (cSecretKey == NULL) {
		fprintf(stderr, "%s: missing ARQ_SECRET_KEY environment variable\n", exeName);
	}
	char *cEncryptionPassword = getenv("ARQ_ENCRYPTION_PASSWORD");
	if (cEncryptionPassword == NULL) {
		fprintf(stderr, "%s: missing ARQ_ENCRYPTION_PASSWORD environment variable\n", exeName);
	}
	if (cAccessKey == NULL || cSecretKey == NULL || cEncryptionPassword == NULL) {
		goto main_error;
	}
	
	NSString *accessKey = [NSString stringWithUTF8String:cAccessKey];
	NSString *secretKey = [NSString stringWithUTF8String:cSecretKey];
	NSString *encryptionPassword = [[[NSString alloc] initWithUTF8String:cEncryptionPassword] autorelease];
    ArqVerifyCommand *cmd = [[[ArqVerifyCommand alloc] initWithAccessKey:accessKey secretKey:secretKey encryptionPassword:encryptionPassword] autorelease];
    NSError *error = nil;
	BOOL ret = NO;
    if (argc == 1) {
		if (![cmd verifyAll:&error]) {
			NSLog(@"%@", [error localizedDescription]);
			goto main_error;
		}
	} else if (argc == 2) {
		if (!strcmp(argv[1], "-?") || !strcmp(argv[1], "-h")) {
			printUsage(exeName);
			goto main_error;
		} else if (![cmd verifyS3BucketName:[NSString stringWithUTF8String:argv[1]] error:&error]) {
			NSLog(@"%@", [error localizedDescription]);
			goto main_error;
		}
	} else if (argc == 3) {
		if (![cmd verifyS3BucketName:[NSString stringWithUTF8String:argv[1]] computerUUID:[NSString stringWithUTF8String:argv[2]] error:&error]) {
			NSLog(@"%@", [error localizedDescription]);
			goto main_error;
		}
	} else if (argc == 4) {
		if (![cmd verifyS3BucketName:[NSString stringWithUTF8String:argv[1]] computerUUID:[NSString stringWithUTF8String:argv[2]] bucketUUID:[NSString stringWithUTF8String:argv[3]] error:&error]) {
			NSLog(@"%@", [error localizedDescription]);
			goto main_error;
		}
	} else {
		printUsage(exeName);
		goto main_error;
    }
	ret = YES;
main_error:
    [pool drain];
    free(exePath);
    return ret ? 0 : 1;
}
