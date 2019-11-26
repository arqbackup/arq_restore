# arq_restore

An open-source command-line utility for restoring from backups created by [Arq](http://www.arqbackup.com/).

Download arq_restore in binary form [here](http://arqbackup.github.io/arq_restore/).


## Usage

Use arq_restore to list the computers backed up to your destination, list folders within a computer, and restore a folder.

Type `arq_restore` with no arguments to get help.

arq_restore works with Arq backups on AWS or a local filesystem. If you need to restore from backups stored at a different cloud provider, download the backup data to a local filesystem and use arq_restore on that.


## Prerequisites

To compile, arq_restore expects OpenSSL 1.0.2 installed in the default location.


## License

    Copyright (c) 2009-2017, Haystack Software LLC http://www.haystacksoftware.com

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

