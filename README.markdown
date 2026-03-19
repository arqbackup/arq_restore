# arq_restore

An open-source command-line macOS utility for restoring from backups created by any version of [Arq](https://www.arqbackup.com/). Supports Arq 5, 6, and 7 backup formats.


## Usage

arq_restore works with Arq backups stored on AWS S3 or on a local filesystem. To restore from backups at another cloud provider, download the backup data to a local path first and point arq_restore at that.

### 1. Configure a target

A *target* is a named pointer to where your backups are stored.

**AWS S3:**
```
arq_restore addtarget <nickname> aws <access_key_id>
```
You will be prompted for your AWS secret key.

**Local filesystem or network volume:**
```
arq_restore addtarget <nickname> local <path>
```

List configured targets:
```
arq_restore listtargets
```

Remove a target:
```
arq_restore deletetarget <nickname>
```

### 2. List computers / backup plans

```
arq_restore listcomputers <nickname>
```

Lists all Arq 5 computer UUIDs and Arq 7 backup plan UUIDs found at the target. Each entry shows the UUID you need for subsequent commands.

### 3. List folders

```
arq_restore listfolders <nickname> <uuid>
```

Lists the backed-up folders for the given computer UUID (Arq 5) or plan UUID (Arq 7), along with their folder UUIDs.

### 4. Browse the file tree

```
arq_restore listtree <nickname> <uuid> <folder_uuid>
```

Prints the file tree from the most recent complete backup of the specified folder.

### 5. Restore

```
arq_restore restore <nickname> <uuid> <folder_uuid> [destination_path]
```

Restores the most recent complete backup of the folder to `destination_path` (defaults to the original path). File contents, permissions, timestamps, and extended attributes are all restored.

### Log level

Pass `-l <level>` immediately after the program name to control log verbosity. Valid levels: `error`, `warn`, `info`, `detail`, `debug`. Example:

```
arq_restore -l debug listcomputers mynas
```


## Data formats

- [arq5_data_format.txt](arq5_data_format.txt) — Arq 5 backup data format
- [arq7_data_format.html](arq7_data_format.html) — Arq 7 backup data format


## Compiling from source

Open `arq_restore.xcodeproj` in Xcode and choose **Product > Build**, or from the command line:

```
xcodebuild -project arq_restore.xcodeproj -scheme arq_restore -configuration Release
```

The built binary will be at `build/Release/arq_restore`.


## License

    Copyright (c) 2009-2026, Haystack Software LLC https://www.arqbackup.com

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
