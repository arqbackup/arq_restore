# arq_restore

An open-source command-line utility for restoring from backups created by [Arq](http://www.haystacksoftware.com/arq/).

Download `arq_restore` in binary form [here](http://sreitshamer.github.com/arq_restore/).


## Usage

First set 3 environment variables:

- `ARQ_ACCESS_KEY`: your S3 access key ID
- `ARQ_SECRET_KEY`: your S3 secret key
- `ARQ_ENCRYPTION_PASSWORD`: the password you used to encrypt your backups


### List Backed-Up Folders

Type `arq_restore` with no arguments to list all backed-up folders.

Example output:

    S3 bucket: akiaiyuk3n3tme6l4hfa.com.haystacksoftware.arq
        Stefan's MacBook Pro (stefan)
            /Users/stefan/src
                UUID:            1D142EAB-3218-48BD-BF5B-4EAEF504783E
                restore command: arq_restore /akiaiyuk3n3tme6l4hfa.com.haystacksoftware.arq/32D9D7A2-3B3E-4BE7-B85B-0605AF24F570/buckets/1D142EAB-3218-48BD-BF5B-4EAEF504783E
            /Users/stefan/Documents
                UUID:            30A9D66D-23FC-4B95-BCA5-864099B87296
                restore command: arq_restore /akiaiyuk3n3tme6l4hfa.com.haystacksoftware.arq/32D9D7A2-3B3E-4BE7-B85B-0605AF24F570/buckets/30A9D66D-23FC-4B95-BCA5-864099B87296
            /Applications
                UUID:            34FD0612-D950-4275-BF4D-EEE5359911C6
                restore command: arq_restore /akiaiyuk3n3tme6l4hfa.com.haystacksoftware.arq/32D9D7A2-3B3E-4BE7-B85B-0605AF24F570/buckets/34FD0612-D950-4275-BF4D-EEE5359911C6
            /Users/stefan/Library
                UUID:            4F86F72A-7D70-4C55-A59A-038B96852C47
                restore command: arq_restore /akiaiyuk3n3tme6l4hfa.com.haystacksoftware.arq/32D9D7A2-3B3E-4BE7-B85B-0605AF24F570/buckets/4F86F72A-7D70-4C55-A59A-038B96852C47
            /Library/Application Support
                UUID:            5C71900E-2303-4B9E-8F00-43083008786F
                restore command: arq_restore /akiaiyuk3n3tme6l4hfa.com.haystacksoftware.arq/32D9D7A2-3B3E-4BE7-B85B-0605AF24F570/buckets/5C71900E-2303-4B9E-8F00-43083008786F
            /Users/stefan/Music
                UUID:            8DA640DA-2F5F-43BE-98A1-02BCD7BA47BD
                restore command: arq_restore /akiaiyuk3n3tme6l4hfa.com.haystacksoftware.arq/32D9D7A2-3B3E-4BE7-B85B-0605AF24F570/buckets/8DA640DA-2F5F-43BE-98A1-02BCD7BA47BD
            /Users/stefan/Pictures/osaka iPhoto Library
                UUID:            CFE285E1-2432-4B10-ABF8-DA78F2C04631
                restore command: arq_restore /akiaiyuk3n3tme6l4hfa.com.haystacksoftware.arq/32D9D7A2-3B3E-4BE7-B85B-0605AF24F570/buckets/CFE285E1-2432-4B10-ABF8-DA78F2C04631
        Mac Mini (stefan)
            /Users/stefan
                UUID:            46B29F51-4201-4A13-BB32-457E77D9481A
                restore command: arq_restore /akiaiyuk3n3tme6l4hfa.com.haystacksoftware.arq/3BA5A6DF-C5EC-409F-9B97-9D437B289BC7/buckets/46B29F51-4201-4A13-BB32-457E77D9481A
        Stefan Reitshamer's iMac (stefan)    (no folders found)
        lisbon (stefan)
            /Users/stefan
                UUID:            65547066-D3FB-4388-80BD-A69D5AB26734
                restore command: arq_restore /akiaiyuk3n3tme6l4hfa.com.haystacksoftware.arq/E8CF6F88-BC09-4E82-9894-25FCC7FD5217/buckets/65547066-D3FB-4388-80BD-A69D5AB26734
            /Applications
                UUID:            BBD8C1EF-4203-4EAA-97CE-552F4E2D2B14
                restore command: arq_restore /akiaiyuk3n3tme6l4hfa.com.haystacksoftware.arq/E8CF6F88-BC09-4E82-9894-25FCC7FD5217/buckets/BBD8C1EF-4203-4EAA-97CE-552F4E2D2B14
            /Library/Application Support
                UUID:            D5B3A8E6-6B7B-44A5-B304-C67D8597E4B0
                restore command: arq_restore /akiaiyuk3n3tme6l4hfa.com.haystacksoftware.arq/E8CF6F88-BC09-4E82-9894-25FCC7FD5217/buckets/D5B3A8E6-6B7B-44A5-B304-C67D8597E4B0
        Stefan's MacBook Pro (withfilevault)    (no folders found)
        Stefan Reitshamer's iMac (stefan)
            /Users/stefan
                UUID:            EABE39F1-386A-4A4E-8DB9-B79F14B38CD6
                restore command: arq_restore /akiaiyuk3n3tme6l4hfa.com.haystacksoftware.arq/ED198467-D8CE-4E8B-90C5-36BF1DBDC694/buckets/EABE39F1-386A-4A4E-8DB9-B79F14B38CD6
    S3 bucket: akiaiyuk3n3tme6l4hfa.com.haystacksoftware.arq.us-west-1
        Stefan's MacBook Pro (stefan)    (no folders found)
    S3 bucket: akiaiyuk3n3tme6l4hfa.com.haystacksoftware.arq.eu    (no computers found)
    S3 bucket: akiaiyuk3n3tme6l4hfa.com.haystacksoftware.arq.ap-southeast-1    (no computers found)


(The word "buckets" in the path should be "folders", but it's not for historical reasons).


### Restore from a Backup

To restore the latest version of one of the folders, type the `restore command` listed.
For example, to restore the `src` folder from `Stefan's MacBook Pro` above, type:

    arq_restore /akiaiyuk3n3tme6l4hfa.com.haystacksoftware.arq/32D9D7A2-3B3E-4BE7-B85B-0605AF24F570/buckets/1D142EAB-3218-48BD-BF5B-4EAEF504783E


## License

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

