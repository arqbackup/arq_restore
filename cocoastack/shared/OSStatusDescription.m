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


#import "OSStatusDescription.h"


@implementation OSStatusDescription
+ (NSString *)descriptionForOSStatus:(OSStatus)status {
    NSString *msg = [(NSString *)SecCopyErrorMessageString(status, NULL) autorelease];
    if (msg == nil) {
        switch (status) {
            case ioErr:
                return @"I/O error"; // GetMacOSStatusCommentString() returns "I/O error (bummers)", which isn't appropriate!
            case nsvErr:
                return @"No such volume";
            case bdNamErr:
                return @"Bad file name";
            case fnfErr:
                return @"File not found";
            case errAuthorizationSuccess:
                return @"The operation completed successfully.";
            case errAuthorizationInvalidSet:
                return @"The set parameter is invalid.";
            case errAuthorizationInvalidRef:
                return @"The authorization parameter is invalid.";
            case errAuthorizationInvalidPointer:
                return @"The authorizedRights parameter is invalid.";
            case errAuthorizationDenied:
                return @"The Security Server denied authorization for one or more requested rights. This error is also returned if there was no definition found in the policy database, or a definition could not be created.";
            case errAuthorizationCanceled:
                return @"The user canceled the operation";
            case errAuthorizationInteractionNotAllowed:
                return @"The Security Server denied authorization because no user interaction is allowed.";
            case errAuthorizationInternal:
                return @"An unrecognized internal error occurred.";
            case errAuthorizationExternalizeNotAllowed:
                return @"The Security Server denied externalization of the authorization reference.";
            case errAuthorizationInternalizeNotAllowed:
                return @"The Security Server denied internalization of the authorization reference.";
            case errAuthorizationInvalidFlags:
                return @"The flags parameter is invalid.";
            case errAuthorizationToolExecuteFailure:
                return @"The tool failed to execute.";
            case errAuthorizationToolEnvironmentError:
                return @"The attempt to execute the tool failed to return a success or an error code.";
        }
    }
    if ([msg length] == 0) {
        msg = [NSString stringWithFormat:@"error %ld", (long)status];
    }
    return msg;
}
@end
