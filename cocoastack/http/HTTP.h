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


#ifndef ARQ_HTTP_H
#define ARQ_HTTP_H

#ifndef HTTP_1_1
#define HTTP_1_1 @"1.1"
#endif
#ifndef HTTP_OK
#define HTTP_OK (200)
#endif
#ifndef HTTP_NO_CONTENT
#define HTTP_NO_CONTENT (204)
#endif
#define HTTP_INTERNAL_SERVER_ERROR (500)
#ifndef HTTP_FORBIDDEN
#define HTTP_FORBIDDEN (403)
#endif
#ifndef HTTP_BAD_REQUEST
#define HTTP_BAD_REQUEST (400)
#endif
#ifndef HTTP_METHOD_NOT_ALLOWED
#define HTTP_METHOD_NOT_ALLOWED (405)
#endif
#ifndef HTTP_REQUEST_TIMEOUT
#define HTTP_REQUEST_TIMEOUT (408)
#endif
#ifndef HTTP_CONFLICT
#define HTTP_CONFLICT (409)
#endif
#define HTTP_REQUESTED_RANGE_NOT_SATISFIABLE (416)
#ifndef HTTP_LENGTH_REQUIRED
#define HTTP_LENGTH_REQUIRED (411)
#endif
#ifndef HTTP_NOT_FOUND
#define HTTP_NOT_FOUND (404)
#endif
#ifndef HTTP_MOVED_PERMANENTLY
#define HTTP_MOVED_PERMANENTLY (301)
#endif
#ifndef HTTP_MOVED_TEMPORARILY
#define HTTP_MOVED_TEMPORARILY (307)
#endif
#define HTTP_SERVICE_NOT_AVAILABLE (503)
#define HTTP_VERSION_NOT_SUPPORTED (505)

#endif /* ARQ_HTTP_H */
