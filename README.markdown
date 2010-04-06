# arq_restore

An open-source command-line utility for restoring from backups created by [Arq](http://www.haystacksoftware.com/arq/).

Download arq_restore in binary form [here](http://sreitshamer.github.com/arq_restore/).


## Usage

First set 3 environment variables:

- `ARQ_ACCESS_KEY`: your S3 access key ID
- `ARQ_SECRET_KEY`: your S3 secret key
- `ARQ_ENCRYPTION_PASSWORD`: the password you used to encrypt your backups


### List Backed-Up Folders

Type `arq_restore` with no arguments to list all backed-up folders.

Example output:

`s3 path=/akiaiyuk3n3tme6l4hfa.com.haystacksoftware.arq/190A155C-2C7C-482A-B813-C1FC89636CDD/buckets/043E24A0-6757-4C88-8D85-68A18E30FFC0   local path=/Users/sreitshamer/Music
s3 path=/akiaiyuk3n3tme6l4hfa.com.haystacksoftware.arq/190A155C-2C7C-482A-B813-C1FC89636CDD/buckets/0CCEC1C6-F75D-4F21-A9F9-4A6D902D8FB9    local path=/Users/sreitshamer/Documents
s3 path=/akiaiyuk3n3tme6l4hfa.com.haystacksoftware.arq/190A155C-2C7C-482A-B813-C1FC89636CDD/buckets/6F7B0740-5623-45C6-8DB8-1701022538BE    local path=/Users/sreitshamer/Pictures/iPhoto Library
s3 path=/akiaiyuk3n3tme6l4hfa.com.haystacksoftware.arq/1C493DC6-FB2C-4EEC-8356-838DABE3AE2C/buckets/3AA39F05-4C47-4CE5-839A-3A28255DD91E    local path=/Users/stefan
s3 path=/akiaiyuk3n3tme6l4hfa.com.haystacksoftware.arq/DFEE2812-B06E-4582-A7C5-C350A7A8C162/buckets/668A7B20-DE9E-49A4-B4E8-78A5CB47B454    local path=/Users/stefan/src
s3 path=/akiaiyuk3n3tme6l4hfa.com.haystacksoftware.arq/DFEE2812-B06E-4582-A7C5-C350A7A8C162/buckets/9322032A-B252-4E50-A474-C591899A241F    local path=/Users/stefan/Documents
`

The `s3 path` value is of the form `/<s3 bucket name>/<computer uuid>/buckets/<folder uuid>`.

(The word "buckets" in the path should be folders, but it's not for historical reasons).


### Restore from a Backup

Type `arq_restore <s3 path>` to restore.


## License

`/*
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
 */`

